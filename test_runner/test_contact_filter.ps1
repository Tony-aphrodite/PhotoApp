# Runtime verification of ContactInfoFilter regex patterns via .NET Regex.
# Patterns mirror lib/core/utils/contact_info_filter.dart verbatim
# (Dart RegExp and .NET Regex share PCRE-compatible syntax for these patterns).

$Email       = [regex]::new('[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}')
$Phone       = [regex]::new('(?:\+?\d[\s\-.()]*){8,}')
$WhatsAppUrl = [regex]::new('(?:wa\.me|api\.whatsapp\.com|chat\.whatsapp\.com)', 'IgnoreCase')
$TelegramUrl = [regex]::new('(?:t\.me|telegram\.me)', 'IgnoreCase')
$Bypass      = [regex]::new(
    '\b(?:whats?\s*app|wha?tsa?pp|wasap|guasap|wapp|telegram|messenger|' +
    'fuera\s+de\s+la\s+app|por\s+fuera|afuera\s+de\s+la\s+app|' +
    'transferencia|deposito\s+directo|pagame\s+por\s+fuera|' +
    'sin\s+la\s+app|sin\s+servitec)\b',
    'IgnoreCase'
)

function Scan([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    if ($Email.IsMatch($text))       { return 'email' }
    if ($WhatsAppUrl.IsMatch($text) -or $TelegramUrl.IsMatch($text)) { return 'externalLink' }
    if ($Phone.IsMatch($text))       { return 'phone' }
    if ($Bypass.IsMatch($text))      { return 'bypassKeyword' }
    return $null
}

# (message, expected_reason_or_null, description)
$cases = @(
    # --- Clean (should NOT trigger) ---
    @('Hola, llego en 20 minutos',           $null, 'Normal greeting'),
    @('Necesito 3 metros de cable',          $null, 'Numbers but not phone-shaped'),
    @('Cost: 1500 pesos for the parts',      $null, 'Short number sequence (4 digits)'),
    @('OK perfecto, nos vemos manana',       $null, 'Plain Spanish text'),
    @('Pieza modelo XR-2034 disponible',     $null, 'Model number (4 digits)'),
    @('',                                    $null, 'Empty string'),
    @('   ',                                 $null, 'Whitespace only'),

    # --- Phone (should trigger phone) ---
    @('Mi numero es 5512345678',             'phone', 'MX 10-digit cell'),
    @('Llamame al +52 55 1234 5678',         'phone', 'International with spaces'),
    @('55-1234-5678',                        'phone', 'Dashed format'),
    @('(55) 1234 5678',                      'phone', 'Parens format'),
    @('Hablame: 5 5 1 2 3 4 5 6 7 8',        'phone', 'Spaced digits'),
    @('Tel 5512345678 disponible',           'phone', 'Phone embedded in sentence'),

    # --- Email ---
    @('Mandame correo a juan@gmail.com',     'email', 'Gmail address'),
    @('contacto: ana.lopez+work@example.co.mx', 'email', 'Complex email'),

    # --- External links ---
    @('Escribeme en wa.me/525512345678',     'externalLink', 'wa.me link'),
    @('https://api.whatsapp.com/send?phone=52', 'externalLink', 'api.whatsapp.com'),
    @('Mi grupo: chat.whatsapp.com/abc',     'externalLink', 'chat.whatsapp.com'),
    @('Mandame en t.me/mychannel',           'externalLink', 't.me link'),
    @('telegram.me/handle',                  'externalLink', 'telegram.me'),
    @('WA.ME/52551234',                      'externalLink', 'Case-insensitive WhatsApp'),

    # --- Bypass keywords ---
    @('Mejor por whatsapp',                  'bypassKeyword', 'whatsapp word'),
    @('Mejor por whats app',                 'bypassKeyword', 'whats app spaced'),
    @('Mandame wasap',                       'bypassKeyword', 'wasap slang'),
    @('Te paso por guasap',                  'bypassKeyword', 'guasap slang'),
    @('Mejor un wapp',                       'bypassKeyword', 'wapp slang'),
    @('Hablamos por telegram',               'bypassKeyword', 'telegram word'),
    @('Mejor en messenger',                  'bypassKeyword', 'messenger'),
    @('Lo arreglamos fuera de la app',       'bypassKeyword', 'fuera de la app'),
    @('Pagame por fuera',                    'bypassKeyword', 'por fuera'),
    @('Hagamos transferencia directa',       'bypassKeyword', 'transferencia'),
    @('Sin la app sale mas barato',          'bypassKeyword', 'sin la app'),
    @('Vamos sin servitec',                  'bypassKeyword', 'sin servitec'),

    # --- Priority ordering ---
    @('juan@x.com 5512345678',               'email',        'Email takes priority over phone'),
    @('Llamame al 5512345678 o wa.me/52',    'externalLink', 'Link beats phone')
)

$passed = 0; $failed = 0; $failures = @()
foreach ($c in $cases) {
    $msg, $expected, $desc = $c
    $actual = Scan $msg
    # PowerShell treats $null comparisons strictly; normalize
    $expectedDisplay = if ($null -eq $expected) { '(clean)' } else { $expected }
    $actualDisplay   = if ($null -eq $actual)   { '(clean)' } else { $actual }
    $ok = ($expected -eq $actual) -or (($null -eq $expected) -and ($null -eq $actual))
    if ($ok) {
        $passed++
        $marker = 'PASS'
    } else {
        $failed++
        $marker = 'FAIL'
        $failures += [pscustomobject]@{ Desc=$desc; Input=$msg; Expected=$expectedDisplay; Actual=$actualDisplay }
    }
    $shown = if ($msg.Length -gt 50) { $msg.Substring(0,50)+'...' } else { $msg }
    "  [{0}] {1,-50} | expected={2,-13} | input='{3}'" -f $marker, $desc, $expectedDisplay, $shown | Write-Output
}

''
"Total: {0}  Passed: {1}  Failed: {2}" -f ($passed + $failed), $passed, $failed | Write-Output

if ($failures.Count -gt 0) {
    ''
    'FAILURES:'
    foreach ($f in $failures) {
        "  - $($f.Desc)"
        "      input    : $($f.Input)"
        "      expected : $($f.Expected)"
        "      got      : $($f.Actual)"
    }
    exit 1
}
'All regex assertions passed.'
