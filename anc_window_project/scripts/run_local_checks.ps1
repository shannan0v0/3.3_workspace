$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$Build = Join-Path $Root 'build'
New-Item -ItemType Directory -Force -Path $Build | Out-Null

function Resolve-Tool([string]$Name, [string[]]$Fallbacks) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Path }
    foreach ($candidate in $Fallbacks) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Run-Captured([string]$Label, [string]$Exe, [string[]]$ToolArgs,
                      [string]$Stdout, [string]$Stderr) {
    Write-Host ("RUN {0}: {1} {2}" -f $Label, $Exe, ($ToolArgs -join ' '))
    $savedErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Exe @ToolArgs 1> $Stdout 2> $Stderr
        $rc = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorAction
    }
    if ($rc -ne 0) {
        Write-Host ("FAIL {0}: RC={1}; see {2} and {3}" -f $Label, $rc, $Stdout, $Stderr)
        exit $rc
    }
    Write-Host ("PASS {0}: RC=0" -f $Label)
}

function Require-Marker([string]$Path, [string]$Pattern, [string]$Label) {
    if (-not (Select-String -Path $Path -Pattern $Pattern -Quiet)) {
        Write-Host ("FAIL {0}: marker {1} not found in {2}" -f $Label, $Pattern, $Path)
        exit 1
    }
    Write-Host ("PASS {0}: marker found" -f $Label)
}

$iverilog = Resolve-Tool 'iverilog.exe' @('D:\iverilog\bin\iverilog.exe', 'C:\iverilog\bin\iverilog.exe')
$vvp      = Resolve-Tool 'vvp.exe'      @('D:\iverilog\bin\vvp.exe', 'C:\iverilog\bin\vvp.exe')
$python   = Resolve-Tool 'python.exe'   @('python.exe', 'C:\Python312\python.exe')
if ($null -eq $iverilog -or $null -eq $vvp -or $null -eq $python) {
    Write-Host 'FAIL missing tool: require iverilog, vvp, and python on PATH or documented fallback paths'
    exit 2
}

$topArgs = @('-g2012','-s','anc_top','-o','build\anc_top.vvp',
    'rtl\anc_fx_lms_core.sv','rtl\anc_reg_bank.sv','rtl\anc_i2s_if.sv','rtl\anc_top.sv')
Run-Captured 'top compile' $iverilog $topArgs 'build\compile_stdout.txt' 'build\compile_stderr.txt'

$coreCompileArgs = @('-g2012','-s','tb_anc_fx_lms_core','-o','build\tb_core.vvp',
    'rtl\anc_fx_lms_core.sv','sim\tb_anc_fx_lms_core.sv')
Run-Captured 'core compile' $iverilog $coreCompileArgs 'build\tb_core_compile_stdout.txt' 'build\tb_core_compile_stderr.txt'
$coreRunArgs = @('build\tb_core.vvp')
Run-Captured 'core simulation' $vvp $coreRunArgs 'build\tb_core_run.txt' 'build\tb_core_run_stderr.txt'
Require-Marker 'build\tb_core_run.txt' '^TB_CORE_PASS$' 'core simulation'

$regCompileArgs = @('-g2012','-s','tb_anc_reg_bank','-o','build\tb_reg.vvp',
    'rtl\anc_reg_bank.sv','sim\tb_anc_reg_bank.sv')
Run-Captured 'register compile' $iverilog $regCompileArgs 'build\tb_reg_compile_stdout.txt' 'build\tb_reg_compile_stderr.txt'
$regRunArgs = @('build\tb_reg.vvp')
Run-Captured 'register simulation' $vvp $regRunArgs 'build\tb_reg_run.txt' 'build\tb_reg_run_stderr.txt'
Require-Marker 'build\tb_reg_run.txt' '^TB_REG_PASS$' 'register simulation'

$pythonArgs = @('scripts\golden_reference.py')
Run-Captured 'python golden reference' $python $pythonArgs 'build\python_golden_run.txt' 'build\python_golden_stderr.txt'
Require-Marker 'build\python_golden_run.txt' '^PY_GOLDEN_PASS$' 'python golden reference'

Write-Host 'LOCAL_CHECKS_PASS'
exit 0
