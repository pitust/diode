# Instrument a VM
import time

gfr = []

def frame(line_info, fn):
    return { 'line': line_info, 'fn': fn }

print(str(lldb.process.Continue()))
while True:
    time.sleep(0.001)
    print(str(lldb.process.Stop()))
    frames = [f for f in [f for f in lldb.process][0]]
    for f in frames:
        gfr.append(frame(str(f.GetLineEntry()), str(f.GetFunctionName())))
    print(str(lldb.process.Continue()))
    with open("frames.txt", "w") as file: file.write('\n'.join([a['fn'] for a in gfr]))