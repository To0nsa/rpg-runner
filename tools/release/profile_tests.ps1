Set-StrictMode -Version Latest

function Get-ReleaseTestTimings {
  param([string[]]$Reports, [int]$Limit = 20)
  $rows = @()
  foreach ($report in $Reports) {
    $tests = @{}
    foreach ($line in Get-Content -LiteralPath $report) {
      if (-not $line.Trim()) { continue }
      $event = $line | ConvertFrom-Json
      if ($event.type -eq "testStart") {
        $tests[$event.test.id] = @{ name = $event.test.name; start = [long]$event.time }
      } elseif ($event.type -eq "testDone" -and $tests.ContainsKey($event.testID)) {
        $test = $tests[$event.testID]
        $rows += [pscustomobject]@{ name = $test.name; milliseconds = [long]$event.time - $test.start; result = $event.result }
      }
    }
  }
  return @($rows | Sort-Object milliseconds -Descending | Select-Object -First $Limit)
}
