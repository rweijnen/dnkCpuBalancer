unit dnkConsoleSplash;

interface

uses
  Windows, SysUtils, Classes, Messages;

const
  WM_TERMINATE = WM_USER + 1;

type
  TSplashThread = class(TThread)
  private
    FTerminateEvent: THandle;
    function GetWindowHandle: THandle;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute; override;
    property WindowHandle: THandle read GetWindowHandle;
    procedure Terminate; reintroduce;
  end;

procedure LoadBitmap;

implementation

const
  WinClassName: PChar = 'dnkSplashClass';
  ResourceName: String = 'SPLASH';


threadvar
  wClass: TWndClass;  // class struct for main window
  hWnd: THandle;
  hInst: THandle;                // handle of program (hinstance)
  Msg: TMSG;             //messages sent to our app
  MemDc: HDC;            //A Mem DC for our Bitmap
  MemBitmap: HBITMAP;    //Our bitmap
  bmi: BITMAP;           //a structure containing the Bitmap Info
  bLoaded: Boolean;

procedure ShutDown;     // we clean up the mem before exit
begin
  Windows.UnRegisterClass(WinClassName, hInst);
  DeleteObject(MemBitmap);
//  ExitProcess(hInst); //end program
end;

procedure PaintSplash;
begin
  if bLoaded then
    BitBlt(GetDC(hWnd), 0, 0, bmi.bmWidth, bmi.bmHeight, MemDc, 0, 0,
      SRCCOPY);
end;

procedure LoadBitmap;
var
  Rect: TRect;
begin
   GetWindowRect(hWnd,Rect);

   MemBitmap := LoadImage(hInst, MAKEINTRESOURCE(ResourceName), { PChar(filename), }IMAGE_BITMAP, 0, 0,
    LR_CREATEDIBSECTION + LR_DEFAULTSIZE{ + LR_LOADFROMFILE});

   GetObject(MemBitmap, SizeOf(Windows.Bitmap), @bmi);

   if (bmi.bmWidth <> 0) and (bmi.bmHeight <> 0) then
   begin
      MemDc := CreateCompatibleDc(getdc(0));
      SelectObject(MemDc, MemBitmap);

      bLoaded := True;
      PaintSplash;
   end;
end;

// This function processes every message sent to our Main window
function WindowProc(hWnd, Msg, wParam, lParam:Longint):Longint; stdcall;
begin
  // Always pass the message to the Default procedure
  Result := DefWindowProc(hWnd,Msg,wParam,lParam);

  //We handle the messages
  case Msg of
    WM_DESTROY: ShutDown;
    WM_PAINT:
    begin
      if not bLoaded then
        LoadBitmap;
      PaintSplash;
    end;
  end;


end;

{ TSplashThread }

constructor TSplashThread.Create;
begin
  FreeOnTerminate := False;
  bLoaded := False;
  FTerminateEvent := CreateEvent(nil, True, False, nil);
  inherited Create(False);
end;

destructor TSplashThread.Destroy;
begin
  CloseHandle(FTerminateEvent);
  inherited;
end;

procedure TSplashThread.Execute;
var
  Width: Integer;
  Height: Integer;
  Top: Integer;
  Left: Integer;
  dwRes: DWORD;
begin
  inherited;

  hInst := GetModuleHandle(nil); // get the application instance

  with wClass do
  begin
    hIcon := LoadIcon(hInst, 'MAINICON');
    lpfnWndProc := @WindowProc;
    hInstance := hInst;
    hbrBackground := COLOR_BTNFACE+1;
    lpszClassName := WinClassName;
  end;

  Windows.RegisterClass(wClass);

  Width := GetSystemMetrics(SM_CXVIRTUALSCREEN);
  Left := GetSystemMetrics(SM_XVIRTUALSCREEN);
  Height := GetSystemMetrics(SM_CYVIRTUALSCREEN);
  Top := GetSystemMetrics(SM_YVIRTUALSCREEN);

  // Center Splash on Monitor(s)
  hWnd := CreateWindowEx(WS_EX_TOOLWINDOW or WS_EX_DLGMODALFRAME or WS_EX_TOPMOST,
    WinClassName, nil, WS_POPUP or WS_VISIBLE,
    (Width - Left - 533) div 2, (Height - Top - 400) div 2, 533, 400,
    GetDesktopWindow, 0, hInst, nil);

{  // Force Message Queue Creation
  PeekMessage(Msg, 0, 0, 0, PM_NOREMOVE);}

  while not Terminated do
  begin
    repeat
      // Wait for terminate or windows message...
      dwRes := MsgWaitForMultipleObjects(1, FTerminateEvent, False, INFINITE,
        QS_ALLINPUT);

      if dwRes <> WAIT_OBJECT_0 then
      begin

        if PeekMessage(Msg, hWnd, 0, 0, PM_REMOVE) then
        begin
          TranslateMessage(Msg);             // Translate any keyboard Msg's
          DispatchMessage(Msg);              // Send it to our WindowProc

          if Msg.message = WM_TERMINATE then
            Terminate;

        end;
      end;
    until dwRes = WAIT_OBJECT_0;
  end;
end;

function TSplashThread.GetWindowHandle: THandle;
begin
  Result := hWnd;
end;

procedure TSplashThread.Terminate;
begin
  inherited Terminate;
  SetEvent(FTerminateEvent);
end;

end.
