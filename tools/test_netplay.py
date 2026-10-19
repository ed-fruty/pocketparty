"""Run four real ENet peers, with isolated test wallets, on loopback."""
import subprocess,time,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
processes=[]
faults='--disconnect' in sys.argv
scene='netplay_disconnect' if faults else 'netplay_peer'
for role in (['host','friend1'] if faults else ['host','friend1','friend2','friend3']):
 log=(root/'builds'/f'{scene}-{role}.log').open('w')
 process=subprocess.Popen(['godot','--headless','--path',str(root),f'res://tests/{scene}.tscn','--',role],stdout=log,stderr=subprocess.STDOUT)
 processes.append((role,process,log))
 time.sleep(.5)
failed=False
for role,process,log in processes:
 try: code=process.wait(timeout=45)
 except subprocess.TimeoutExpired:
  process.kill();process.wait();code=124
 log.close()
 output=(root/'builds'/f'{scene}-{role}.log').read_text()
 print(role,'exit',code)
 messages=[line for line in output.splitlines() if 'NETPLAY' in line or 'DISCONNECT' in line or 'ERROR' in line or 'Error' in line]
 for line in messages[:20]: print(line)
 if len(messages)>20: print('additional messages:',len(messages)-20)
 failed|=code!=0 or 'SCRIPT ERROR' in output
raise SystemExit(1 if failed else 0)
