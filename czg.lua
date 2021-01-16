local DHI = {}			--- DAMAGE HIT ITERATOR
DHI.instances = {}
DHI.instances.IDM = 0
DHI.instances.UA = 0
DHI.instances.SH = 0
DHI.instances.PC = 0

DHI.spell = nil
local DHIList = {}

DHI.IDM = 		{roll = {95,85,75,50}, inc = {1.15, 1.35, 1.575, 1.85}}
DHI.UA =		{roll = {80,75,70,50}, inc = {1.05,1.15,1.25,1.5}}
DHI.SH = {}				-- Spell hit
DHI.SH[2] = 	{roll = {95,90,80,50}, bound = 3000}
DHI.SH[11] = 	{roll = {100,100,100,80}}
DHI.SH[20] = 	{roll = {100,100,90,50}}
DHI.SH[22] = 	{roll = {100,100,100,70}, bound = 2500}
DHI.SH[27] =	{roll = {100,95,80,50}}
DHI.SH[29] =	{roll = {100,100,90,60}}
DHI.PC = {}				-- Poison Counter
DHI.PC.mobs = {}

DHI.handlingChain = false

function DHI.IDM:run(t)
	DHI.instances.IDM = DHI.instances.IDM + 1
	local didNotKill = t.Result < t.Monster.HP and true or false
	local s,m = SplitSkill(t.Player.Skills[const.Skills.IdentifyMonster])
	if didNotKill then
		if math.random(0,100) > DHI.IDM.roll[m] then
			t.Result = math.floor(t.Result * DHI.IDM.inc[m])
			if t.Result > t.Monster.HP then
				Game.ShowStatusText("Critical! " .. tostring(t.Player.Name) .. " dealt " .. tostring(t.Result) .. " damage to " .. tostring(Game.MonstersTxt[t.Monster.Id].Name .. ", killing them!"),5)
				
				t.Monster.HP, t.Monster.HitPoints = 0, 0								
				t.Monster.AIState = 4
				mem.call(0x42694B, 1, Game.MonstersTxt[t.Monster.Id].Experience)
			else
				Game.ShowStatusText("Critical! " .. tostring(t.Player.Name) .. " dealt " .. tostring(t.Result) .. " damage to " .. tostring(Game.MonstersTxt[t.Monster.Id].Name), 5)
			end
		end
	end
	
	return t, self:destroy()
end

function DHI.IDM:destroy()
	DHI.instances.IDM = DHI.instances.IDM - 1
	self = nil
end

function DHI.UA:run(t)
	DHI.instances.UA = DHI.instances.UA + 1
	local didNotKill = t.Result < t.Monster.HP and true or false
	local s,m = SplitSkill(t.Player.Skills[const.Skills.Unarmed])
	if didNotKill then
		if math.random(0,100) > DHI.UA.roll[m] then
			t.Result = math.floor(t.Result * DHI.UA.inc[m])
			if t.Result > t.Monster.HP then
				Game.ShowStatusText("Critical! " .. tostring(t.Player.Name) .. " dealt " .. tostring(t.Result) .. " damage to " .. tostring(Game.MonstersTxt[t.Monster.Id].Name .. ", killing them!"),5)
				
				t.Monster.HP, t.Monster.HitPoints = 0, 0								
				t.Monster.AIState = 4
				mem.call(0x42694B, 1, Game.MonstersTxt[t.Monster.Id].Experience)
			else
				Game.ShowStatusText("Critical! " .. tostring(t.Player.Name) .. " dealt " .. tostring(t.Result) .. " damage to " .. tostring(Game.MonstersTxt[t.Monster.Id].Name), 5)
			end
		end
	end
	return t, self:destroy()
end

function DHI.UA:destroy()
	DHI.instances.UA = DHI.instances.UA - 1
	self = nil
end

function DHI.PC:run(t)
	DHI.instances.PC = DHI.instances.PC + 1

	return t, self:destroy()
end

function DHI.PC:destroy()
	DHI.instances.PC = DHI.instances.PC - 1
	self = nil
end

function DHI.SH:run(t)
	DHI.instances.SH = DHI.instances.SH + 1
	local chance = math.random(0, 100)
	local s, m, sk = self.spell.Spell, self.spell.Mastery. self.spell.Skill
	if s == 2												-- Fire Bolt
		if chance > DHI.SH[s].roll[m] + (t.Monster.FireResistance - sk) then
			DHI:chainNew(self.spell, t, false)
		end
	elseif spell.Spell == 11 then 							-- Incinerate
		if chance > DHI.SH[s].roll[m] + (t.Monster.FireResistance - sk) then
			local Buff = t.Monster.SpellBuffs[const.MonsterBuff.ArmorHalved]
			Buff.ExpireTime = math.max(Game.Time + const.Minute*sk, Buff.ExpireTime)
		end
	elseif spell.Spell == 20 then							-- Implosion
		DHI:suckNearbyTo(t)
	elseif s == 22 then										-- Lightning Bolt
		if chance > DHI.SH[s].roll[m] + (t.Monster.AirResistance - sk) then
			DHI:chainNew(self.spell, t, false)
		end
	elseif spell.Spell == 37 or spell.Spell == 39 then		-- Blades / Rock Blast
		if chance > DHI.SH[s].roll[m] + (t.Monster.EarthResistance - sk) then
			local Buff = t.Monster.SpellBuffs[const.MonsterBuff.Slow]
			Buff.ExpireTime = math.max(Game.Time + const.Minute*sk, Buff.ExpireTime)
		end
	else
	end
	return t, self:destroy()
end

function DHI.SH:destroy()
	DHI.instances.SH = DHI.instances.SH - 1
	self = nil
end

function DHI:new(t, data)
	local item = nil
	if t == "idmonster" then 
		item = self:create(self.IDM)
	elseif t == "unarmed" then
		item = self:create(self.UA)
	elseif t == "poison" then
		if self.instances.PC == 0 then
			item = self:create(self.PC)
		else
			
		end
	else
		item = self:create(self.SH)
	end
	if self.spell then item.spell = self.spell end
	return item:run(data)
end

function DHI:create(source)
	local copies = {}
    local orig_type = type(source)
    local copy
    if orig_type == 'table' then
        if copies[source] then
            copy = copies[source]
        else
            copy = {}
            copies[source] = copy
            for orig_key, orig_value in next, source, nil do
                copy[self:create(orig_key, copies)] = self:create(orig_value, copies)
            end
            setmetatable(copy, self:create(getmetatable(source), copies))
        end
    else
        copy = source
    end
    return copy
end

function DHI:chainNew(spell, source, lb)
	if self.handlingChain then 
		local dOC = math.random(1,100)
		if spell.Spell == 2 then dOC = 100 end
		if dOC > 33 then
			self.handlingChain = false
			return
		end
	end
	local target = source.Monster
	local sourcePos = {X = target.X, Y = target.Y, Z = target.Z}
	local closestBounds = 0
	local canHitTwice = math.random(0, 100) > 75 and true or false
	
	for _,m in Game.Map.Monsters do
		if m.HostileType == 0 or canHitTwice or (m.AIState == 4 or m.AIState == 5 or AIState == 11) then goto skipper end
		if m.X == Party.X and m.Y == Party.Y and m.Z == Party.Z then goto skipper end
		
		local mBound = math.sqrt((sourcePos.X - m.X)^2 + (sourcePos.Y - m.Y)^2 + (sourcePos.Z - m.Z)^2)
		
		if closestBounds < mBound then 
			closestBounds = mBound
			target = m
		end
		::skipper::
	end
	if (closestBounds < DHI.SH[spell.Spell].bound and closestBounds > -DHI.SH[spell.Spell].bound) and target.HostileType ~= 2 then
		if canHitTwice then
			Game.ShowStatusText("Double " .. tostring(Game.SpellsTxt[spell.Spell].Name) .. " was cast on " .. tostring(Game.MonstersTxt[source.Monster.Id].Name), 5)
		end
		evt.CastSpell(spell.Spell,spell.Mastery,spell.Skill,sourcePos.X + 25,sourcePos.Y + 25,sourcePos.Z + 200,target.X,target.Y,target.Z)
	end
	if not lb then self.handlingChain = true end
end

function DHI:suckNearbyTo(t)
	local mob = t.Monster
	local pos = {X = mob.X, Y = mob.Y, Z = mob.Z}
	
	for _,m in Game.Map.Monsters do
		if m.HostileType == 0 then goto suckSkip end
		if m == mob then goto suckSkip end
		if m.AIState == 4 or m.AIState == 5 or AIState == 11 then goto suckSkip end
		local mBound = math.sqrt((pos.X - m.X)^2 + (pos.Y - m.Y)^2 + (pos.Z - m.Z)^2)
		local newPos = {X = 0, Y = 0, Z = 0}
		
		if mBound < 1200 then
			if mob.X > m.X then newPos.X = m.X + 100 else newPos.X = m.X - 100 end
			if mob.Y > m.Y then newPos.Y = m.Y + 100 else newPos.Y = m.Y - 100 end
		
			if newPos.X ~= nil then
				m.X = newPos.X
				m.Y = newPos.Y
			end
		end
		::suckSkip::
	end
	return
end

function events.CalcSpellDamage(t)
	DHI.spell = t
end

function events.CalcDamageToMonster(t)
	local source = t.Player or nil
	if source then
		if t.DamageKind == const.Damage.Phys then
			local uSkill, idSkill = 0, 0
		
			for _,p in Party do
				local i = SplitSkill(p.Skills[const.Skills.IdentifyMonster])
				local u = SplitSkill(p.Skills[const.Skills.Unarmed])
				if i ~= 0 then
					idSkill = math.max(idSkill, i)
				end
				if source == p then
					if u ~= 0 then
						uSkill = math.max(uSkill, u)
					end
				end
			end
			
			if idSkill > 0 then
				 t = DHI:new("idmonster", t)
			end
			
			if uSkill > 0 then
				t = DHI:new("unarmed", t)
			end
		else
			if DHI.spell then
				if table.find({24, 29, 90}, DHI.spell.Spell) then
					t = DHI:new("poison", t)
				else
					t = DHI:new("spell", t)
				end
			end
		end
		Game.ShowStatusText(tostring(t.Player), 50)
	end
end
