import re,sys
# digest of a decompiled grim lua file: for every top level function, the state changing lines
pat=re.compile(r'(:get\(\)|put_in_limbo|:free\(\)|\.owner\s*=|cur_puzzle_state|switch_to_set|come_out_door|Dialog:run|start_script\(cut_scene|cut_scene\.|\bTRUE\b|\bFALSE\b|\.node\s*=|\.off\s*=|_door:|unlock|:lock|make_touchable|make_untouchable|set_object_state|walkOut|owner ~?=|\bif\b.*(owner|talked|seen|got|has|is_holding|solved|met|said|used|\.[a-z_]+ then)|\belseif\b|\bend_dialog|Sentence|MakeSectorActive)')
skip=re.compile(r'say_line|wait_for|head_look|gesture|sleep_for|play_chore|stop_chore|push_chore|fade_|set_talk|set_mumble|print_costumes|blend|SetActorShadow|AddShadow|set_costume|start_sfx|stop_sound|ExpireText|NewObjectState|\.use_(pnt|rot)|\.out_(pnt|rot)|use_pnt|use_rot|out_pnt|out_rot|walkto|walk_and_face|turn_|setpos|setrot|set_look|set_rest|set_walk|set_head|music_state|Actor:create')
def main(path, only=None):
    lines=open(path,errors='replace').read().split('\n')
    cur=None; buf=[]
    out=[]
    def flush():
        if cur and buf:
            out.append(cur); out.extend(buf)
    for i,l in enumerate(lines):
        m=re.match(r'^([A-Za-z_][\w\.\[\]]*) = (function|Object:create|Dialog:create)',l)
        m2=re.match(r'^([A-Za-z_][\w\.\[\]]*)\s*=\s*\{ text',l)
        if m or m2:
            flush(); buf=[]
            cur=(m or m2).group(1)+('  (obj)' if m and m.group(2)!='function' else '')
            if m2: cur+='  [dialog line] '+l.strip()[:80]
            continue
        if cur and pat.search(l) and not skip.search(l):
            buf.append('   '+l.strip()[:150])
    flush()
    print('\n'.join(out))
if __name__=='__main__':
    main(sys.argv[1])
