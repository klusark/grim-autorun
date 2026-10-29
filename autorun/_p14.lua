ar_wait_for_control()
local names = {"cf","cc","ci","cn","ce","cl","bi","be","bw","hb","dd","lx","lm","xb","jb","tb","hh","gt","bb","bp","pc","ev","mg","pi","sl","hl","mx","ts","kh","ks","hk","hp","he","de","dh","wc","tx","se","si","tw","bk"}
local i = 1
while names[i] do
	local s = getglobal(names[i])
	if s then
		s:switch_to_set()
		manny:put_in_set(s)
		sleep_for(1500)
		ar_log("##### SET " .. names[i])
		ar_describe()
	end
	i = i + 1
end
exit()
