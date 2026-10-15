# Windows x64 development-only startup capture, using the standard debug API.
# Requires the local executable and PDB. Stack entries are candidates, not an
# unwound backtrace. Expected first-chance guest memory faults are passed to
# ReXGlue. Stops the debug-launched game after a fatal exception or 40 seconds.
import ctypes as c, pathlib, subprocess, struct, time
from ctypes import wintypes as w
root=pathlib.Path(__file__).resolve().parents[1]
exe=root/'out/build/win-amd64-release/fable_3.exe'
k=c.WinDLL('kernel32',use_last_error=True); dbg=c.WinDLL('dbghelp',use_last_error=True)
k.WaitForDebugEvent.argtypes=[c.c_void_p,w.DWORD]; k.ContinueDebugEvent.argtypes=[w.DWORD,w.DWORD,w.DWORD]
k.OpenThread.argtypes=[w.DWORD,w.BOOL,w.DWORD]; k.OpenThread.restype=w.HANDLE
k.GetThreadContext.argtypes=[w.HANDLE,c.c_void_p];k.ReadProcessMemory.argtypes=[w.HANDLE,c.c_void_p,c.c_void_p,c.c_size_t,c.POINTER(c.c_size_t)]
dbg.SymInitializeW.argtypes=[w.HANDLE,w.LPCWSTR,w.BOOL];dbg.SymFromAddr.argtypes=[w.HANDLE,c.c_ulonglong,c.POINTER(c.c_ulonglong),c.c_void_p]
dbg.SymSetOptions(0x12)
p=subprocess.Popen([str(exe),'--game_data_root',str(root/'game')],cwd=exe.parent,creationflags=2)
h=w.HANDLE(int(p._handle)); event=c.create_string_buffer(176); base=0; t0=time.monotonic(); initialized=False;breakpoints=0
try:
 while time.monotonic()-t0<40:
  if not k.WaitForDebugEvent(event,500): continue
  kind,pid,tid=struct.unpack_from('<III',event.raw)
  if kind==3: base=struct.unpack_from('<Q',event.raw,40)[0]
  if kind==1:
   code=struct.unpack_from('<I',event.raw,16)[0];fault=struct.unpack_from('<Q',event.raw,56)[0]
   if code==0xc0000005 and struct.unpack_from('<I',event.raw,168)[0]:
    k.ContinueDebugEvent(pid,tid,0x80010001); continue
   if code==0x80000003: breakpoints+=1
   if code in (0xc0000005,0xc0000409,0xc000001d,0xc0000094) or (code==0x80000003 and breakpoints>1):
    th=k.OpenThread(0x8|0x40,False,tid);ctx=c.create_string_buffer(1232+16);addr=(c.addressof(ctx)+15)&~15; c.c_uint32.from_address(addr+48).value=0x10001f
    if not k.GetThreadContext(th,addr): raise c.WinError(c.get_last_error())
    raw=c.string_at(addr,1232);rip=struct.unpack_from('<Q',raw,248)[0];rsp=struct.unpack_from('<Q',raw,152)[0]
    print(f'EXCEPTION code={code:x} fault={fault:x} rip={rip:x} image_base={base:x}',flush=True)
    if not initialized: print('Symbols:',bool(dbg.SymInitializeW(h,str(exe.parent),True)),flush=True);initialized=True
    def symbol(a):
     info=c.create_string_buffer(4096);struct.pack_into('<I',info,0,88);struct.pack_into('<I',info,80,3000);disp=c.c_ulonglong()
     if dbg.SymFromAddr(h,a,c.byref(disp),info):return info.raw[84:].split(b'\0')[0].decode(errors='replace')+f'+0x{disp.value:x}'
     return '?'
    print('FAULT:',symbol(rip),flush=True)
    buf=c.create_string_buffer(8192);n=c.c_size_t();k.ReadProcessMemory(h,rsp,buf,len(buf),c.byref(n));seen=set()
    for off in range(0,n.value-7,8):
     a=struct.unpack_from('<Q',buf.raw,off)[0]
     if base<=a<base+0x8000000 and a not in seen:
      seen.add(a); print(f'STACK CANDIDATE +{off:x}: {a:x} {symbol(a)}',flush=True)
      if len(seen)>=24:break
    break
   status=0x10002 if code==0x80000003 else 0x80010001
  else: status=0x10002
  k.ContinueDebugEvent(pid,tid,status)
  if kind==5:
   print('PROCESS EXIT',struct.unpack_from('<I',event.raw,16)[0],flush=True);break
finally:
 if p.poll() is None:p.terminate()
