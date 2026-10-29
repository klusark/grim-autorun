import re,sys
# fn.py file name [name ...] : prints the bodies of the named top level functions, without dialogue noise
skip=re.compile(r'say_line|wait_for_message|wait_for_chore|wait_for_actor|head_look|gesture\(|sleep_for|play_chore|stop_chore|push_chore|fade_|set_talk|set_mumble|print_costumes|blend|SetActorShadow|AddShadow|start_sfx|stop_sound|ExpireText|walk_and_face|turn_(left|right)|set_look|set_rest|set_walk|set_head|music_state|preload_sfx|ImSet|set_collision|SetActorCollision|^\s*$')
def main():
    path=sys.argv[1]; names=sys.argv[2:]
    lines=open(path,errors='replace').read().split('\n')
    i=0
    while i<len(lines):
        l=lines[i]
        m=re.match(r'^([A-Za-z_][\w\.\[\]]*) = function',l)
        if m and any(m.group(1)==n or m.group(1).endswith('.'+n) for n in names):
            print(l.strip()[:120]); i+=1
            while i<len(lines) and not re.match(r'^[A-Za-z_][\w\.\[\]]* = ',lines[i]):
                if not skip.search(lines[i]): print(lines[i][:150])
                i+=1
            continue
        i+=1
main()
