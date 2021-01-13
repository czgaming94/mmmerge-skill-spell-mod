local DHI = {}			--- DAMAGE HIT ITERATOR
DHI.instances.IDM = 0
DHI.instances.UA = 0
DHI.instances.SH = 0
DHI.instances.PC = 0

DHI.spell = nil
local DHIList = {}

DHI.IDM = {roll = {95,85,75,50}, inc = {1.15, 1.35, 1.575, 1.85}}
DHI.UA = {roll = {80,75,70,50}, inc = {1.05,1.15,1.25,1.5}}
DHI.SH = {}				-- Spell hit
DHI.SH[2] = {roll = {95,90,85,60}}
DHI.PC = {}				-- Poison Counter
DHI.PC.mobs = {}

function DHI.IDM:run(t)
	DHI.instances.IDM = DHI.instances.IDM + 1
	local s,m = SplitSkill(t.Player.Skills[const.Skills.IdentifyMonster])
	if math.random(0,100) > DHI.IDM.roll[m] then
		t.Result = math.floor(t.Result * DHI.IDM.inc[m])
	end
	return t, self:destroy()
end

function DHI.IDM:destroy()
	DHI.instances.IDM = DHI.instances.IDM - 1
	self = nil
end

function DHI.UA:run(t)
	DHI.instances.UA = DHI.instances.UA + 1
	local s,m = SplitSkill(t.Player.Skills[const.Skills.Unarmed])
	if math.random(0,100) > DHI.UA.roll[m] then
		t.Result = math.floor(t.Result * DHI.UA.inc[m])
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
	local chanceRoll = math.random(0, 100)
	if self.spell.Spell == 2 then
		if chanceRoll > DHI.SH[self.spell.Spell].roll[self.spell.Mastery] then
			DHI:chainNew(self.spell, t)
		end
	elseif self.spell.Spell == 22 then
	
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

function DHI:chainNew(spell, source)
	local closest = source.Monster
	local pos = {X = source.Monster.X, Y = source.Monster.Y, Z = source.Monster.Z}
	local partyPos = {X = Party.X, Y = Party.Y, Z = Party.Z}
	local closestBounds = 0
	local canHitTwice = false
	if math.random(0, 100) > 75 then canHitTwice = true end
	
	for _,m in Game.Map.Monsters do
		if m.HostileType == 0 or canHitTwice or (m.AIState == 4 or m.AIState == 5 or AIState == 11) then goto skipper end
		if m.X == partyPos.X and m.Y == partyPos.Y and m.Z == partyPos.Z then goto skipper end
		
		local mBound = math.sqrt((pos.X - m.X)^2 + (pos.Y - m.Y)^2 + (pos.Z - m.Z)^2)
		
		if closestBounds < mBound then 
			closestBounds = mBound
			closest = m
		end
		::skipper::
	end
	
	if (closestBounds < 4000 and closestBounds > -4000) and closest.HostileType ~= 2 then
		if canHitTwice then
			Game.ShowStatusText("Double " .. tostring(Game.SpellsTxt[spell.Spell].Name) .. " was cast on " .. tostring(Game.MonstersTxt[mob.Monster.Id].Name), 5)
		end
		evt.CastSpell(spell.Spell,spell.Mastery,spell.Skill,pos.X + movePos[spell.Spell][1],pos.Y + movePos[spell.Spell][2],pos.Z + movePos[spell.Spell][3],closest.X,closest.Y,closest.Z)
	end
end

function events.CalcSpellDamage(t)
	DHI.spell = t
end

function events.CalcDamageToMonster(t)
	local source	
	for _,pl in Party do
		if t.Player == pl then source = pl end
	end
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
