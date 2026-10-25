"""Offline checks: no client binary, extracted client API or user saves required."""
from pathlib import Path
import hashlib,re,sys
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parent.parent
addon=root/'AzerothStats'
toc=(addon/'AzerothStats.toc').read_text(encoding='utf-8')
assert '## Interface: 11200' in toc and '## SavedVariables: AzerothStatsDB' in toc
modules=[line.strip() for line in toc.splitlines() if line.strip() and not line.startswith('#')]
assert len(modules)==18 and set(modules)=={p.name for p in addon.glob('*.lua')}
version=re.search(r'^## Version: (.+)$',toc,re.M)[1].strip()
assert ('version = "'+version+'"') in (addon/'Util.lua').read_text(encoding='utf-8')
# Inspect Lua 5.1 prototypes for the stricter Lua 5.0 upvalue ceiling.
class Chunk:
    def __init__(self,b):
        self.b=b;self.pos=12;self.order='little' if b[6] else 'big';self.isize=b[7];self.ssize=b[8];self.ins=b[9];self.numsize=b[10];self.maximum=0;self.proto()
    def n(self,size):
        value=int.from_bytes(self.b[self.pos:self.pos+size],self.order);self.pos+=size;return value
    def integer(self):return self.n(self.isize)
    def string(self):
        size=self.n(self.ssize);self.pos+=size
    def proto(self):
        self.string();self.integer();self.integer();self.maximum=max(self.maximum,self.n(1));self.pos+=3
        count=self.integer();self.pos+=count*self.ins
        for _ in range(self.integer()):
            kind=self.n(1)
            if kind==1:self.pos+=1
            elif kind==3:self.pos+=self.numsize
            elif kind==4:self.string()
            else:assert kind==0
        for _ in range(self.integer()):self.proto()
        count=self.integer();self.pos+=count*self.isize
        for _ in range(self.integer()):self.string();self.integer();self.integer()
        for _ in range(self.integer()):self.string()
compiler=LuaRuntime(encoding=None)
compile_lua=compiler.eval(b'function(s) local f,e=loadstring(s);assert(f,e);return string.dump(f) end')
for path in sorted(addon.rglob('*.lua')):
    raw=path.read_bytes();assert not raw.startswith(b'\xef\xbb\xbf'),path
    chunk=Chunk(compile_lua(raw));assert chunk.maximum<=32,(path,chunk.maximum)
    if path.parent==addon:
        assert not re.search(rb'(?m)^\s*[^-\n].*(?:\bgoto\b|\bstring\.gmatch\b|\btable\.unpack\b|\bselect\s*\(|(?<![<>=~])#)',raw),path
        code=re.sub(rb'"(?:[^"\\]|\\.)*"',b'""',raw);code=re.sub(rb'--[^\n]*',b'',code)
        assert b'...' not in code and b'%' not in code,path
for line in (addon/'SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():
    digest,name=line.split('  ',1);p=addon/name
    assert addon.resolve() in p.resolve().parents
    assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,('release byte drift',name)
for name in ['AzerothSans.ttf','AzerothSerif.ttf','AzerothSans-zh.otf','AzerothSans-ja.otf','AzerothSans-ko.otf','OFL-NotoSans.txt','OFL-NotoCJK.txt']:
    assert (addon/'media'/name).is_file(),name
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((addon/'tests/mock.lua').read_text(encoding='utf-8-sig'))
for name in modules:lua.execute((addon/name).read_text(encoding='utf-8'))
lua.execute((addon/'tests/serialize.lua').read_text(encoding='utf-8'))
lua.execute((addon/'tests/ci_smoke.lua').read_text(encoding='utf-8-sig'))
lua.execute('TEST_COUNT=CI_CHECKS')
lua.execute((addon/'tests/favorites_deaths.lua').read_text(encoding='utf-8'))
lua.execute('CI_CHECKS=TEST_COUNT')
print('PASS:',len(modules),'production modules; Lua syntax/upvalue checks; TOC; release manifest; font notices;',lua.globals().CI_CHECKS,'offline assertions')
