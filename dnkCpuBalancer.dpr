program dnkCpuBalancer;

{.$APPTYPE CONSOLE}
{$R *.dres}
{$R *.res}
{$A+} {record alignment on 4 byte boundaries}
{$Z4}

uses
  Windows,
  SysUtils,
  Math,
  JwaNative,
  JwaWinType,
  JwaNtStatus,
  dnkConsoleSplash in 'dnkConsoleSplash.pas';

type
  _PROCESS_BASIC_INFORMATION = record
    ExitStatus: Long;
    PebBaseAddress: PEB;
    AffinityMask: ULONG_PTR;
    BasePriority: DWORD;
    UniqueProcessId: DWORD;
    InheritedFromUniqueProcessId: DWORD;
  end;
  PROCESS_BASIC_INFORMATION = _PROCESS_BASIC_INFORMATION;
  PPROCESS_BASIC_INFORMATION = ^PROCESS_BASIC_INFORMATION;
  TProcessBasicInformation = PROCESS_BASIC_INFORMATION;
  PProcessBasicInformation = ^TProcessBasicInformation;

function CpuCount: DWORD;
var
  sbi: TSystemBasicInformation;
  cbSize: DWORD;
  nts: NTSTATUS;
begin
  ZeroMemory(@sbi, SizeOf(sbi));
  nts := NtQuerySystemInformation(SystemBasicInformation, @sbi, SizeOf(sbi),
    @cbSize);

  if nts <> STATUS_SUCCESS then
  begin
    Result := 1;
    Exit;
  end;

  Result := sbi.NumberProcessors and sbi.ActiveProcessors;
end;

function CpuNoToAffinityMask(const Cpu: DWORD): DWORD;
begin
  Result := Trunc(Power(2, Cpu-1));
end;

function GetParentProcessId: DWORD;
var
  pbi: TProcessBasicInformation;
  nts: NTSTATUS;
  cbSize: DWORD;
begin
  nts := NtQueryInformationProcess(GetCurrentProcess, ProcessBasicInformation,
    @pbi, SizeOf(pbi), @cbSize);
  if nts = STATUS_SUCCESS then
  begin
    Result := pbi.InheritedFromUniqueProcessId;
  end
  else begin
    MessageBox(0, 'Failed', 'DEBUG', MB_OK);
    Result := GetCurrentProcessId;
  end;
end;
procedure DoIt;
var
  RandomCpu: DWORD;
  AffinityMask: DWORD;
  hProcess: DWORD;
  ParentPid: DWORD;
begin
  Randomize;

  RandomCpu := RandomRange(1, CpuCount);
  AffinityMask := CpuNoToAffinityMask(RandomCpu);
  ParentPid := GetParentProcessId;
  hProcess := OpenProcess(PROCESS_SET_INFORMATION, False, ParentPid);
  Win32Check(hProcess <> 0);
  try
    Win32Check(SetProcessAffinityMask(hProcess, AffinityMask));
    SleepEx(2000, True);
  finally
    CloseHandle(hProcess);
  end;
end;

var
  SplashThread: TSplashThread;
begin
  SplashThread := TSplashThread.Create;
  DoIt;
  SplashThread.Terminate;
  SplashThread.WaitFor;
  SplashThread.Free;
end.
