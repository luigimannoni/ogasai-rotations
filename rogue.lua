--[[
		Original script from Beniamin, forked and readapted for a better automation
		http://darkenedlinux.com/ogasai/member.php?action=profile&uid=22
	]]

--[[ TODOs:
	- Refine 1-10 leveling
	- Better analyse the surroundings, often the bot kills itself with 2 mobs or a mob which can't cope with
	- Flee from mobs
	- Make navigation more human-alike
	- Reply to whispers
	- Trigger Repair/Sell routine
	- Check for new gear to equip, bags, etc
	- Review existing code
	- Dynamic settings, be aware of what we can eat or rec
	- Cooking(?)
]]

--[[CGObject_C = 0,
    CGItem_C,
    CGContainer_C,
    CGUnit_C,
    CGPlayer_C,
    CGGameObject_C,
    CGDynamicObject_C,
    CGCorpse_C,]]

bot_ = 1;
--Debug
debug_ = 1;
SetPVE(1)
--Bot Settings
local eatHealth = 85; -- number (percent)
local throwOpener = true; -- use throw insteaad of stealth opener (boolean)
local stealthDistance = 30; -- distance to use Stealth from enemy before opening (number)
--stopLootNearestDis = 25; -- If Enemy is within yards, then do not loot (number)
local dismountRange = 30; -- dismount when play is at least yards close (number)
local mountRange = 80; -- mount when the player is at least yards far (number)
local throwWeapon = 'Small Throwing Dagger'; -- string or table of strings
local mainHandPoisonName = {'Instant Poison V'}; -- string or table of strings
local offHandPoisonName = {'Instant Poison V'}; -- string or table of strings
local foodList = {"Charred Wolf Meat", "Crispy Bat Wing"} -- string or table of strings
local lowerLevelRange = 5; -- enemy level range BELOW player's level
local upperLevelRange = 1; -- enemy level range ABOVE player's level
local potionList = {"Minor Healing Potion","potion2"}; -- string or table of strings
local usePotionHealth = 10; -- percentage of player's health to use a healing potion
local bandageList = {"bandage1", "bandage2"}; -- list of bandages
local mountBuff = "Pinto Horse"; -- mount and look at your mount buff, NOT the item name in you bag. This is a bug workaround. 

local safeMobBool = true; -- BETA TEST
local enemyPlayerSafeMobRange = 100;-- the range in which the safe mob can be from enemy players

local avoidPlayersBool = true-- BETA TEST
local enemyPlayerAvoidRange = 40;

local adrenalineRushAOE = true -- only use adrenaline rush for aoe and never for 1 target

--local skinningRadius = 25;

local ambushOpener = true;
local pullDistance = 200;
local throwStopTime = 3;
---------------------------------------------------------------------------------------
--- DO NOT EDIT PAST HERE --- DO NOT EDIT PAST HERE --- DO NOT EDIT PAST HERE --- kthx
---------------------------------------------------------------------------------------
function round(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

function Cast(spellName, target)
	if HasSpell(spellName) == 1
	and IsSpellInRange(target, spellName) == 1
	and IsSpellOnCD(spellName) == 0 
	and IsAutoCasting(spellName) == 0 then
		FaceTarget(target);
		AutoAttack(target);
		CastSpellByName(spellName);
		debugText = "Cast spell "..spellName;
		return true;
	end
	return false;
end
function RogueBuff(spellName) 
	local localObj = GetLocalPlayer()
	if HasSpell(spellName) == 1
	and IsSpellOnCD(spellName) == 0
	and HasBuff(localObj, spellName) == 0 then
		CastSpellByName(spellName);
		debugText = "Cast buff "..spellName;
		return true;
	end
	return false;
end
function IsTimeGood()
	if (GetVar('timer') < GetTimeX()) then
		return 1;
	end
	return 0;
end
function UpdateTimer(time)
	SetVar('timer', GetTimeX() + time*1000);
end
if IsChanneling() == 1 or IsCasting() == 1 then
	SetVar('PoisonTimer', GetTimeX() + 3000);
end
function ApplyPoisons()
	if GetVar('PoisonTimer') < GetTimeX() then
		return 1;
	end
	return 0;
end

function CheckPoisons()
	local localObj = GetLocalPlayer();
	local hasMainHandEnchant, _, _,  hasOffHandEnchant, _, _ = GetWeaponEnchantInfo();
	if not hasMainHandEnchant or not hasOffHandEnchant then
		if IsInCombat() == 0 and IsChanneling() == 0 and IsCasting() == 0 and ApplyPoisons() == 1 and IsEating() == 0 and (Loot() == 0 or canLoot == false) then
			if hasMainHandEnchant == nil then
				if type(mainHandPoisonName) == "string" then mainHandPoisonName = {mainHandPoisonName} end;
				for _,v in pairs(mainHandPoisonName) do
					if v == "" or v == nil or  type(v) ~= "string" then
						v = "nil"
					end
					local MHPoison = HasItem(v);
					if MHPoison == 1 then
						if (IsStanding() == 0 or IsMoving() == 1) then
							StopMoving();
							debugText = "Stop moving for poison";
							return true;
						end
						if HasBuff(localObj, mountBuff) == 1 then
							Dismount();
							debugText = "Dismount for poison";
							return true;
						end
						UseItem(v);
						PickupInventoryItem(16);
						debugText = "Apply Poison to mainhand";
						return true;
					end
				end
			elseif hasOffHandEnchant == nil then
				if type(offHandPoisonName) == "string" then offHandPoisonName = {offHandPoisonName} end;
				for _,v in pairs(offHandPoisonName) do
					if v == "" or v == nil or  type(v) ~= "string" then
						v = "nil"
					end
					local OHPoison = HasItem(v);
					if OHPoison == 1 then
						if (IsStanding() == 0 or IsMoving() == 1) then
							StopMoving();
							debugText = "Stop moving for poison";
							return true;
						end
						if HasBuff(localObj, mountBuff) == 1 then
							Dismount();
							debugText = "Dismount for poison";
							return true;
						end
						UseItem(v);
						PickupInventoryItem(17);
						debugText = "Apply posion to offhand";
						return true;
					end
				end
			end
		end
	end
	return false;
end

function EquipThrow()
	local localObj = GetLocalPlayer();
	if type(throwWeapon) == "string" then throwWeapon = {throwWeapon} end;
	for _,v in pairs(throwWeapon) do
		if v == "" or v == nil or  type(v) ~= "string" then
			v = "nil"
		end
		if HasRangedWeapon(localObj) == 0 and HasItem(v) == 1 then
			UseItem(v);
			debugText = "Equip thrown weapon "..v;
			return true;
		end
	end
	return false;
end

function DeBugInfo()
	-- color
	local r = 255;
	local g = 2;
	local b = 233;
	-- position
	local y = 150;
	local x = 25;
	-- info
	if debugText == nil then debugText = "" end;
	DrawText(debugText, x, y, r, g, b); y = y + 15;
	DrawLine(15, 150, 15, 178, r, g, b, 2);
end

function EnemyAOE(radius) -- return number of enemies
    local unitsAoE = 0;
	local localObj = GetLocalPlayer();
	for i, v in pairs(objectTable) do
		if v.type == 3 then
			if CanAttack(i) == 1
			and IsDead(i) == 0
			and IsCritter(i) == 0 
			and ((IsTapped(i) == 0 or IsTappedByMe(i) == 1) or GetUnitsTarget(i) == localObj) then
				local objDistance = GetDistance(i);
				if objDistance < radius then
					unitsAoE = unitsAoE + 1;
				end
			end
		end
	end
	return unitsAoE;
end

function RunAway(target) -- function to run away (the number of enemies above level) and what kind of object
	ResetNavigate();
	if specificTarget == nil then specificTarget = 0 end;
	if IsMoving() == 1 and (runningAway == true and specificTarget == target) then -- we are already runinng away from the target
		return true;
	else
		runningAway = false;
	end
	local localObj = GetLocalPlayer();
	if target ~= 0 then
		local xT, yT, zT = GetUnitsPosition(target);
		local xP, yP, zP = GetUnitsPosition(localObj);
		local distance = GetDistance(target); -- this is represent the vector magnitude (or at least should)
		local xV, yV, zV = xP - xT, yP - yT, zP - zT -- vector of the target going towards the player
		local vectorLength = math.sqrt(xV^2 + yV^2 + zV^2) -- confirmed working
		local xUV, yUV, zUV = (1/vectorLength)*xV, (1/vectorLength)*yV, (1/vectorLength)*zV
		local moveX, moveY, moveZ = xT + xUV*120, yT + yUV*120, zT + zUV*120
		Move(moveX, moveY, moveZ);
		specifictTarget = target; -- we run away from the specific target only once
		runningAway = true; -- we need a variable to confirm the movement we are executing is the movement of this function
		return true;
	end
end

function GetFurthestFriendlyUnit()
	local localObj = GetLocalPlayer();
	local furthestFriendly = 0;
	for i,v in pairs(objectTable) do
		if (CanAttack(i) == 0 or IsCritter(i) == 1 or IsDead(i) == 1)
		and i ~= localObj then
			furthestFriendly = (getDistance(i) > GetDistance(furthestFriendly) or furthestFriendly == 0) and i or furthestFriendly;
		end
	end
end	

-- this is a very shitty way to check if we can riposte
function CanRiposte()
	for i=1,132 do
		local texture = GetActionTexture(i);
		if texture ~= nil and string.find(texture,"Ability_Warrior_Challange") then
			local isUsable, _ = IsUsableAction (i);
			if isUsable == 1 then
				return true;
			end		
		end
	end
	return false;
end
-- this is a very shitty way to check if we can ambush
function CanAmbush()
	for i=1,132 do
		local texture = GetActionTexture(i);
		if texture ~= nil and string.find(texture,"Ability_Rogue_Ambush") then
			local isUsable, _ = IsUsableAction (i);
			if isUsable == 1 then
				return true;
			end		
		end
	end
	return false;
end
function GetNearestMobAggroed()
	local localObj = GetLocalPlayer();
	local closestEnemy = 0;
	for i, v in pairs(objectTable) do
		if v.type == 3 then
			if CanAttack(i) == 1
			and IsDead(i) == 0
			and GetUnitsTarget(i) == localObj then
				closestEnemy = (GetDistance(i) < GetDistance(closestEnemy) or closestEnemy == 0) and i or closestEnemy;
			end
		end
	end
	return closestEnemy;
end
function GetNearestPlayerAggroed()
	local localObj = GetLocalPlayer();
	local closestEnemy = 0;
	for i, v in pairs(objectTable) do
		if v.type == 4 then
			if CanAttack(i) == 1
			and IsDead(i) == 0
			and GetUnitsTarget(i) == localObj then
				closestEnemy = (GetDistance(i) < GetDistance(closestEnemy) or closestEnemy == 0) and i or closestEnemy;
			end
		end
	end
	return closestEnemy;
end

function GetNearestEnemyPlayer() 
	local currentObj, typeObj = GetFirstObject();
	local localObj = GetLocalPlayer();
	local closestEnemy = 0;
	for i, v in pairs(objectTable) do
		if v.type == 4 then
			if CanAttack(i) == 1
			and IsDead(i) == 0 then
				closestEnemy = (GetDistance(i) < GetDistance(closestEnemy) or closestEnemy == 0) and i or closestEnemy;
			end
		end
	end
	return closestEnemy;
end

function GetNearestPlayer()
	local localObj = GetLocalPlayer();
	local closestEnemy = 0;
	for i, v in pairs(objectTable) do
		if v.type == 4 then
			if IsDead(i) == 0 then
				closestEnemy = (GetDistance(i) < GetDistance(closestEnemy) or closestEnemy == 0) and i or closestEnemy;
			end
		end
	end
	return closestEnemy;
end

function GetObjects()
	objectTable = {};
	local obj_, type_ = GetFirstObject();
	while obj_ ~= 0 do
		if type_ == 3 or type_ == 4 then
			local objX, objY, objZ = GetUnitsPosition(obj_);
			local objR = GetLevel(obj_) - GetLevel(GetLocalPlayer()) + 25
			local objGUID = GetGUID(obj)
			objectTable[obj_] = {x = objX, y = objY, z = objZ, type = type_, r = objR, GUID = objGUID};
		end
		obj_, type_ = GetNextObject(obj_);
	end
end

function DrawCircles(pointX,pointY,pointZ,radius, redVar, greenVar, blueVar, lineThickness, quality)
	local r = 255;
	local g = 2;
	local b = 233;
	-- position
	local x = 25;
	-- info
	if debugText == nil then debugText = "" end;
	
	-- we will go by radians, not degrees
	local sqrt, sin, cos, PI, theta, points, point = math.sqrt, math.sin, math.cos,math.pi, 0, {}, 0;
	while theta <= 2*PI do
		point = point + 1 -- get next table slot, starts at 0 
		points[point] = { x = pointX + radius*cos(theta), y = pointY + radius*sin(theta) }
		theta = theta + 2*PI / quality -- get next theta
	end
	for i = 1, point do
		local firstPoint = i
		local secondPoint = i + 1
		if firstPoint == point then
			secondPoint = 1
		end
		if points[firstPoint] and points[secondPoint] then
			local x1, y1, onScreen1 = WorldToScreen(points[firstPoint].x, points[firstPoint].y, pointZ)
			local x2, y2, onScreen2 = WorldToScreen(points[secondPoint].x, points[secondPoint].y, pointZ)
			if onScreen1 == 1 and onScreen2 == 1 then
				DrawLine(x1, y1, x2, y2, redVar, greenVar, blueVar, lineThickness)
			end
		end
	end
end

function GetNearestSafeMob(mobCount,lowerLevel,upperLevel)
	local localObj = GetLocalPlayer();
	local xP, yP, zP = GetUnitsPosition(localObj);
	local closestEnemy = 0;
	local objList = {};
	local objCount = 0;
	local currentTarget = GetTarget();
	-- gather all the mobs in the area, put them in a table with x, y, z, and mob count
	for i,v in pairs(objectTable) do
		if v.type == 3 then
			if CanAttack(i) == 1
			and IsDead(i) == 0 
			and ((IsTapped(i) == 0 or IsTappedByMe(i) == 1) or GetUnitsTarget(i) == localObj)
			and IsCritter(i) == 0 then
				objList[i] = { x = v.x, y = v.y, z = v.z, r = v.r, mobCount = 0, mobInteresectCount = 0 };
			end
		end
	end
	-- get the number of mobs around each mob based on aggro range
	for object1, var1 in pairs(objList) do
		for object2, var2 in pairs(objList) do
			if object1 ~= object2 then -- don't compare the same object to itself
				local objDistance = math.sqrt( (var1.x - var2.x)^2 + (var1.y - var2.y)^2 + (var1.z - var2.z)^2  )
				local aggroRadius = var2.r
				if var2.r > objDistance then
					objList[object1].mobCount = objList[object1].mobCount + 1;
				end
				if LineSphereIntersection(xP,yP,zP, var1.x,var1.y,var1.z, var2.x,var2.y,var2.z, var2.r) then
					objList[object1].mobInteresectCount = objList[object1].mobInteresectCount + 1;
				end
			end
		end
	end
	-- remove mobs around enemy players
	for i,v in pairs(objectTable) do
		if v.type == 4
		and CanAttack(i) == 1
		and IsDead(i) == 0 then
			for j, k in pairs(objList) do
				local objDistance = math.sqrt( (v.x - k.x)^2 + (v.y - k.y)^2 + (v.z - k.z)^2  )
				if enemyPlayerSafeMobRange > objDistance then
					objList[j] = nil
				end
			end
		end
	end
	-- if the mob is safe to aggro, find the mob closest to player
	for safeMob, varSafe in pairs(objList) do
		if varSafe.mobCount < mobCount
		and GetLevel(safeMob) >= GetLevel(localObj) - lowerLevel
		and GetLevel(safeMob) <= GetLevel(localObj) + upperLevel
		and varSafe.mobInteresectCount == 0
		and GetDistance(safeMob) <= pullDistance then
			closestEnemy = (GetDistance(safeMob) < GetDistance(closestEnemy) or closestEnemy == 0) and safeMob or closestEnemy;
		end
	end
	return closestEnemy;
end
	
function UpdateObjectTimer()
	SetVar("ObjectTimer", GetTimeX() + 1000);
end

function ObjectTimer()
	if GetVar("ObjectTimer") < GetTimeX() then
		return true;
	end
	return false;
end

function UpdateMovementPauseTimer(time)
	SetVar("MovementPauseTimer", GetTimeX() + time*1000);
end

function MovementPauseTimer()
	if GetVar("MovementPauseTimer") < GetTimeX() then
		return true;
	end
	return false;
end

function LineSphereIntersection(xl1,yl1,zl1,xl2,yl2,zl2,xc,yc,zc,r) -- two points for the line
	local xV, yV, zV = xl2 - xl1, yl2 - yl1, zl2 - zl1;
	local A = xV^2 + yV^2 + zV^2;
	local B = 2*( xV*xl1 - xV*xc + yV*yl1 - yV*yc + zV*zl1 - zV*zc );
	local C = xl1^2 - 2*xl1*xc + xc^2 + yl1^2 - 2*yl1*yc + yc^2  + zl1^2 - 2*zl1*zc + zc^2 - r^2;
	local D = B^2 - 4*A*C;
	local t1 = (-B - math.sqrt(D)) / (2*A);
	local t2 = (-B + math.sqrt(D)) / (2*A);
	if (D < 0 or t1 > 1 or t2 > 1 or t1 < 0 or t2 < 0) then
		return false
	else 
		return true
	end
end
-----------------------------------
-- UPDATE OBJECTS EVERY ONE SECOND --
--if ObjectTimer() then
	GetObjects();
	--UpdateObjectTimer();
--end
if (debug_ == 1) then
	DeBugInfo();
	for i,v in pairs(objectTable) do
		-- DRAW CIRCLES AROUND MOBS (AGGRO RANGE)
		if IsDead(i) == 0
		and v.type == 3
		and CanAttack(i) == 1
		and IsCritter(i) == 0 then
			DrawCircles(v.x,v.y,v.z,v.r, 255, 255, 0, 1, 30)
		end
	end
	-- DRAW CIRCLES FOR MOBS AND ENEMY PLAYERS
	for i,v in pairs(objectTable) do
		if IsDead(i) == 0
		and v.type == 4
		and CanAttack(i) == 1
		and IsCritter(i) == 0 then
			DrawCircles(v.x,v.y,v.z,50, 255, 0, 0, 1, 30)
		end
	end
end

local localObj = GetLocalPlayer();
local localEnergy = GetEnergy(localObj);
local localHealth = GetHealthPercentage(localObj);
local localLevel = GetLevel(localObj);
local localComboPoints = GetComboPoints(localObj);
local canLoot = true;
local canEat = true;
local mobPullCount = (HasSpell("Blade Flurry") and IsSpellOnCD("Blade Flurry") == 0 and localHealth > 90) and 2 or 1;

-- VANISH MECHANISM --
if bot_ == 1 then
	if (HasBuff(localObj,"Stealth") == 1 or HasBuff(localObj,"Vanish") == 1) then
		if localHealth < eatHealth then
			local nearestEnemyMob = GetNearestEnemy();
			if nearestEnemyMob ~= 0 then
				local mobAggroRange = GetLevel(nearestEnemyMob) - GetLevel(GetLocalPlayer()) + 30
				if (GetDistance(nearestEnemyMob) < mobAggroRange) then
					RunAway(nearestEnemyMob);
					return;
				elseif IsMoving() == 1 then
					StopMoving();
				end
			end
		end
	end
end

-- RUN AWAY FROM ENEMY PLAYERS WHEN OUT OF COMBAT / RUN AWAY FROM ENEMY PLAYERS WHEN NO MOBS TO PULL
if avoidPlayersBool == true then 
	local nearestEnemyPlayer = GetNearestEnemyPlayer();
	if nearestEnemyPlayer ~= 0 
	and IsInCombat() == 0 
	and GetLevel(localObj) <= GetLevel(nearestEnemyPlayer)
	and IsDead(localObj) == 0 then
		canLoot = false;
		-- dismount if enemy near
		if HasBuff(localObj, mountBuff) == 1 then
			Dismount();
			return;
		end
		-- Don't eat if Stealthed around enemy players
		if HasBuff(localObj, "Stealth") then
			canEat = false;
		end
		-- Stealth
		if RogueBuff("Stealth") then
			return
		end
		-- if enemy is close, run away
		if GetDistance(nearestEnemyPlayer) < enemyPlayerAvoidRange then
			RunAway(nearestEnemyPlayer);
			return
		else
			-- run away from enemy player to find mobs
			local nearestSafeEnemyMob = GetNearestSafeMob(mobPullCount,lowerLevelRange,upperLevelRange)
			local nearestSafeMob = (GetLevel(localObj) <= 3 or safeMobBool == false) and GetNearestEnemy() or nearestSafeEnemyMob
			if nearestSafeMob == 0 then
				RunAway(nearestEnemyPlayer);
				return
			end
		end
	end
end
-- TARGETTING -- 
if (bot_ == 1) then
	-- The nearest enemy player is attacking you
	local nearestPlayerAggroed = GetNearestPlayerAggroed();
	local lastTarget = GetTarget();
	-- if an enemy player is targetting us and no mobs are attacking us
	if nearestPlayerAggroed ~= 0 
	and GetLevel(localObj) - 3 < GetLevel(nearestPlayerAggroed)
	then
		-- enemy player is in combat with us
		if IsInCombat() == 1 then
		-- target enemy to see if he's in combat
			-- run out of range
			if GetDistance(nearestPlayerAggroed) < 35 and RogueBuff("Sprint") then
				debugText = "EnemyPlayer is targetting us in combat, Sprint";
				return;
			end
			-- vanish out of sight
			if HasItem('Flash Powder') == 1 
			and GetDistance(nearestPlayerAggroed) < 40
			and RogueBuff("Vanish") then
				debugText = "Vanishing from enemy player"
				return
			end
			-- get out of view range
			if GetDistance(nearestPlayerAggroed) <= 100 then	
				-- run away from only players
				debugText = "Running away from players targetting us"
				RunAway(nearestPlayerAggroed);
				return
			else
				-- don't move if we are out of enemy player's range
				if IsMoving() == 1 then
					StopMoving();
				end
				return
			end
		else
			-- Cast stealth if an enemy player has us targetted
			if RogueBuff("Stealth") then
				debugText = "Enemy player has us targetted, Stealth"
				return;
			end
		end
	else
		local nearestMobAggroed = GetNearestMobAggroed();
		local nearestSafeMob = (GetLevel(localObj) <= 3 or safeMobBool == false) and GetNearestEnemy() or GetNearestSafeMob(mobPullCount,lowerLevelRange,upperLevelRange)
		-- clear target
		if lastTarget ~= 0
		and IsDead(lastTarget) == 0
		and CanAttack(lastTarget) == 1
		and ((IsInCombat() == 1 and (IsTappedByMe(lastTarget) == 0 and IsTapped(lastTarget) == 1 and GetUnitsTarget(lastTarget) ~= localObj))
		or (IsInCombat() == 0 and lastTarget ~= nearestSafeMob)) then
			debugText = "Clearing current target because our current target unit is not a safe target (changing targets)"
			ClearTarget();
			return;
		end
		-- if the target is fleeing from us, then keep chasing
		if lastTarget ~= 0 and IsDead(lastTarget) == 0 and CanAttack(lastTarget) == 1 and IsFleeing(lastTarget) == 1 then
			targetObj = lastTarget
		-- if the target is targetting us, attack it
		elseif lastTarget ~= 0  and IsDead(lastTarget) == 0 and CanAttack(lastTarget) == 1 and GetUnitsTarget(lastTarget) == localObj then
			targetObj = lastTarget
		-- if a nearby mob is attacking us, attack it
		elseif GetNearestMobAggroed() ~= 0 then
			targetObj = GetNearestMobAggroed();
		-- if the target is tapped by us or is targetting us
		elseif (lastTarget ~= 0 and IsDead(lastTarget) == 0 and CanAttack(lastTarget) == 1 and ((IsTapped(lastTarget) == 0 or IsTappedByMe(lastTarget) == 1) or GetUnitsTarget(lastTarget) == localObj)) then
			targetObj = lastTarget;
		else
			-- find a new mob
			targetObj = nearestSafeMob
		end
	end
	distance = GetDistance(targetObj);
	SetMinTargetLevel(GetLevel(localObj) - lowerLevelRange);
	SetMaxTargetLevel(GetLevel(localObj) + upperLevelRange);
else
	targetObj = GetTarget();
end

--[[if (bot_ == 1) then
	SetPVE(1)
	local currentTarget = GetTarget();
	local nearestEnemy = GetNearestEnemy();
	if currentTarget ~= 0 then
		-- apply filters for enemy players or enemy player pets
		if UnitIsPlayer("target")
		or UnitPlayerControlled("target") then
			debugText = "Current target is enemy player or enemy player controlled, clearing and pausing rotation";
			ClearTarget();
			if Mount() == 1 then
				if (IsMoving() == 1) then
					StopMoving();			
				end
				return;
			end
			if (Navigate() == 1) then
				return;
			else
				StopMoving();
			end
		end
	elseif nearestEnemy ~= 0 then
		TargetEnemy(nearestEnemy);
		if UnitIsPlayer("target")
		or UnitPlayerControlled("target") then
			debugText = "Nearest enemy is enemy player or enemy player controlled, clearing and pausing rotation";
			ClearTarget();
			if Mount() == 1 then
				if (IsMoving() == 1) then
					StopMoving();			
				end
				return;
			end
			if (Navigate() == 1) then
				return;
			else
				StopMoving();
			end
		end
	end
end]]

-- CASTING/CHANNELING RETURN
if (IsChanneling() == 1 or IsCasting() == 1) then
	return;
end
-- ROTATION MOVEMENT AND BOT OUT OF COMBAT
if (bot_ == 0) then
	if (IsMoving() == 1) then
		return;
	end
else
	if IsInCombat() == 0 then
		local currentTarget = GetTarget();
	--(IsInCombat() == 0) then
		--canSkin = true;
		if (IsDead(localObj) == 1) then
			Grave();
			targetObj = 0;
			canLoot = false;
			canEat = false;
			--canSkin = false;
			debugText = "Died, release and return to body (no lootnil target)";
			return;
		end
		--[[if (GetDistance(GetNearestEnemy()) < stopLootNearestDis) then
			canLoot = false;
		end]]
		if (canLoot == true and Loot() == 1)  then
			targetObj = 0;
			canEat = false;
			--canSkin = false;
			debugText = "Looting (out of combat)";
			return;
		end
		if canLoot == true and (currentTarget ~= 0 and IsDead(currentTarget) == 1) and LootTarget() == 1 then
			targetObj = 0;
			canEat = false;
			debugText = "We are able to loot the target"
			return
		end
		if canLoot == true and IsLooting() == 1 then
			targetObj = 0;
			canEat = false;
			debugText = "We are currently looting"
			return;
		end
		if IsTimeGood() == 0 then
			targetObj = 0;
			canLoot = false;
			canEat = false;
			--canSkin = false;
			debugText = "Recently used food, momentarily pausing (no lootnil target)";
			return;
		end
		if (localHealth < eatHealth) then
			targetObj = 0;
			canLoot = false;
			--canSkin = false;
			debugText = "We are low, waiting to recuperate health (no lootnil target)";
		end
		if ((IsEating() == 1 or IsStanding() == 0) and localHealth < 100) then
			targetObj = 0;
			canLoot = false;
			--canSkin = false;
			debugText = "Eating/sitting, waiting for full health (no lootnil target)"
		end
		-- this is buggy, trying to fix it
		-- if enemy is close by, don't loot
		--[[
		if (targetObj ~= 0 and GetDistance(targetObj) < stopLootNearestDis) then
			canLoot = false;
		end]]
		--Loot
		--[[if (canSkin == true and SkinDead(skinningRadius) == true) then
			targetObj = 0;
			debugText = "Skinning in "..skinningRadius.." radius"; 
			return;
		end]]
		--Vendor
		if (canLoot == true and Vendor() == 1) then
			targetObj = 0;
			if (CanMerchantRepair()) then 
				RepairAllItems();
			end
			debugText = "Vendoring (out of combat)";
			return;
		end
		if CheckPoisons() == true then
			targetObj = 0;
			debugText = "Applying Poisons (out of combat)";
			return
		end
	end
end
-- EQUIP THROW --
if EquipThrow() == true then
	return;
end

-- ENEMY OBJECT
if (targetObj ~= 0) then
	-- Cant Attack dead targets
	if (IsDead(targetObj) == 1) then
		debugText = "Target is dead (target)";
		return;
	end
	if (CanAttack(targetObj) == 0) then
		debugText = "Cannot attack target (target)";
		return;
	end
	targetHealth = GetHealthPercentage(targetObj);
	-- ENEMY OBJECT BOT -- 
	if (bot_ == 1) then	
		--if (IsMoving() == 1) then
		--	StopMoving();
		--	return;
		--end
		if (IsStanding() == 0) then
			StopMoving();
			debugText = "Stand up (target)";
			return;
		end
	end
	-- OUT OF COMBAT --
	if (IsInCombat() == 0) then
		if bot_ == 1 then
			-- mountdismount
			if GetDistance(targetObj) < dismountRange then
				if HasBuff(localObj, mountBuff) == 1 then
					Dismount();
					debugText = "You are within "..dismountRange.." yards, dismounting (out of combattarget)";
					return;
				end
			elseif GetDistance(targetObj) > mountRange then
				if IsTimeGood() == 1 and ApplyPoisons() == 1 and IsSwimming() == 0 then
					if Mount() == 1 then
						if (IsMoving() == 1) then
							StopMoving();			
						end
						debugText = "You are further than "..mountRange.." yards, mounting (out of combattarget)";
						return;
					end
				end
			end
			if (GetDistance(targetObj) > 8 or IsInLineOfSight(targetObj) == 0) and MovementPauseTimer() == true then
				MoveToTarget(targetObj);
				ResetNavigate();
				debugText = "Moving to target (in combat)"
			else
			-- face target if in melee range
				FaceTarget(targetObj);
			end
		end
		local hasStealth = HasSpell('Stealth');
		-- use throw or stealth
		if (throwOpener == true) then
			if (HasRangedWeapon(localObj) == 1) then -- needs weapon
				if (IsInLineOfSight(targetObj) == 1) then
					if (GetDistance(targetObj) > 13) then
						if (Cast('Throw', targetObj)) then -- if in range, then target, throw and stop
							ResetNavigate();
							UpdateMovementPauseTimer(throwStopTime)
							--AutoAttack(targetObj); 
							if (IsMoving() == 1) then
								StopMoving();
								debugText = "Stopping to cast throw (opener)";
								return
							end
							debugText = "Casting Throw at target (opener)";
							return;
						end
					end
				end
			end
			AutoAttack(targetObj);
			if  MovementPauseTimer() == false then
				if (IsMoving() == 1) then
					StopMoving();			
				end
			end
		else
			if (hasStealth == 1) then
				-- if we don't have Stealth buff, then use stealth
				if (GetDistance(targetObj) < stealthDistance) then
					if RogueBuff('Stealth') then
						debugText = "You are within "..stealthDistance..", casting Stealth";
						return;
					end
				end
				-- make a function to cast distract on the opposite side of the enemy
				-- cast Cheap Shot if we can, else cast AmbushGarrote
				if HasBuff(localObj,'Stealth') == 1 then
					-- Cast Premeditation first if we can before opening
					if Cast('Premeditation', targetObj) then
						debugText = "Casting Premeditation";
						return;
					end
					if CanAmbush() and ambushOpener == true and Cast('Ambush', targetObj) then
						debugText = "Casting Ambush";
						return;
					elseif (Cast('Cheap Shot', targetObj)) then
						debugText = "Casting Cheap Shot";
						return;
					elseif (Cast('Garrote', targetObj)) then
						debugText = "Casting Garrote";
						return;
					end
				end	
			--else
				--AutoAttack(targetObj);
			end
		end
	-- COMBAT --
	else
		-- if bot, move to target and reset nav
		if (bot_ == 1) then
			-- Find best path after combat
			--ResetNavigate();
			--if GetDistance(targetObj) < dismountRange then
				if HasBuff(localObj, mountBuff) == 1 then
					Dismount();
					debugText = "Dismounting in combat"
					--debugText = "You are within "..dismountRange.." yards, dismounting (combattarget)";
					return;
				end
			--end
			if (GetDistance(targetObj) > 8 or IsInLineOfSight(targetObj) == 0) and MovementPauseTimer() == true then
				MoveToTarget(targetObj);
				ResetNavigate();
				debugText = "Moving to target (out of combattarget)"
			else
			-- face target if in melee range
				FaceTarget(targetObj);
			end
		end
		-- if the target is fleeing, throw
		if (IsFleeing(targetObj) == 1) then
			if (HasRangedWeapon(localObj) == 1) then -- needs weapon
				if (IsInLineOfSight(targetObj) == 1) then
					if (GetDistance(targetObj) > 13) then
						if (Cast('Throw', targetObj)) then -- if in range, then target, throw and stop
							ResetNavigate();
							if (IsMoving() == 1) then
								StopMoving();
								debugText = "Stopping to cast Throw (fleeing)";
								return;
							end
							debugText = "Casting Throw (fleeing)";
							return;
						end
					end
				end
			end
		end
		-- if not stealthed, attack
		if (HasBuff('Stealth', localObj) == 0) then
			--AutoAttack(targetObj); 
			if (localHealth < usePotionHealth) then
				if type(potionList) == "string" then potionList = {potionList} end;
				for _,v in pairs (potionList) do
					if v == "" or v == nil or  type(v) ~= "string" then
						v = "nil"
					end
					if HasItem(v) == 1 then
						if UseItem(v) == 1 then
							UpdateTimer(0.5);
							debugText = "Using "..v.."(combat)";
						end
					end
				end
			end
		end
		--hasSinisterStrike = HasSpell('Sinister Strike');
		local hasEviscerate = HasSpell('Eviscerate');
		local hasEvasion = HasSpell('Evasion');
		local hasVanish = HasSpell('Vanish'); -- requires Flash Powder
		-- talent specific
		local hasBladeFlurry = HasSpell('Blade Flurry');
		local hasColdBlood = HasSpell('Cold Blood');
		local hasAdrenalineRush = HasSpell('Adrenaline Rush');
		-- evasion
		if (hasEvasion == 1) then
			if ((localHealth < 50 and localHealth < targetHealth) or  EnemyAOE(8) > 1) and GetUnitsTarget(targetObj) == localObj then
				if RogueBuff('Evasion') then
					debugText = "Cast Evasion because we are low";
					return;
				end
			end
		end
		-- use Vanish if really low
		if (hasVanish == 1) then
			if (localHealth < 5) then
				if (HasItem('Flash Powder') == 1) then
					if RogueBuff("Vanish") then
						debugText = "Cast Vanish because we are low";
						return;
					end
				end
			end
		end
		-- Since there are multiple ways to generate CP, lets make a function
		function generateCP() -- returns spell string
			-- Riposte (proc)
			-- Ghostly Strike (cd)
			-- Hemorrhage (debuff)
			-- Sinister Strike
			if (HasSpell('Ghostly Strike') == 1 and IsSpellOnCD('Ghostly Strike') == 0) then
				return 'Ghostly Strike';
			elseif (HasSpell('Hemorrhage') == 1 and IsSpellOnCD('Hemorrhage') == 0 and HasDebuff(targetObj, 'Hemorrhage') == 0) then
				return 'Hemorrhage';
			elseif (HasSpell('Sinister Strike') == 1 and IsSpellOnCD('Sinister Strike') == 0) then
				return 'Sinister Strike';
			else 
				return nil;
			end
		end
		-- Adrenaline Rush
		if EnemyAOE(8) > 1 or adrenalineRushAOE == false then
			if (GetDistance(targetObj) < 5) then
				if RogueBuff('Adrenaline Rush') then
					debugText = "Cast Adrenaline Rush";
					return;
				end
			end
		end
		-- Blade Flurry
		if EnemyAOE(8) > 1 then
			if (GetDistance(targetObj) < 5) then
				if RogueBuff('Blade Flurry') then
					debugText = "Cast Blade Flurry";
					return;
				end
			end
		end
		if (HasSpell('Riposte') == 1 and IsSpellOnCD('Riposte') == 0 and CanRiposte()) then -- Needs Riposte function 
			if Cast("Riposte", targetObj) then
				return;
			end
		end
		-- 5 CP
		if (localComboPoints == 5) then
			-- eviscerate at 5 CP
			if (hasEviscerate == 1) then
				__, __, __, __, EviscerateCost = GetSpellInfoX('Eviscerate');
				if (localEnergy >= EviscerateCost) then
					-- use Cold Blood for 5 CP eviscerate
					if RogueBuff('Cold Blood') then
						debugText = "Cast Cold Blood";
						return;
					end
					if (Cast('Eviscerate', targetObj)) then
						debugText = "Cast 5CP Eviscerate";
						return;
					end
				end
			end
		-- dynamic health check to eviscerate between 1 and 4 CP
		elseif (localComboPoints < 5 and localComboPoints > 0) then
			if (hasEviscerate == 1) then
				-- if target's health is below 5% per combo point
				if (targetHealth < 5*localComboPoints) then
					__, __, __, __, EviscerateCost = GetSpellInfoX('Eviscerate');
					if (localEnergy >= EviscerateCost) then
						if (Cast('Eviscerate', targetObj)) then
							debugText = "Target is below "..5*localComboPoints..", cast "..localComboPoints.."CP Eviscerate";
							return;
						end
					end
				-- if target is not low, continue to use a CP generator
				elseif (generateCP() ~= nil and HasSpell(generateCP()) == 1) then
					__, __, __, __, abilityCost = GetSpellInfoX(generateCP());
					if (abilityCost ~= nil and localEnergy >= abilityCost) then
						if (Cast(generateCP(), targetObj)) then
							if generateCP() ~= nil then
								debugText = "Cast "..generateCP();
							end
							return;
						end
					end
				end
			end
		-- 0 CP, obviously use a CP builder
		elseif (localComboPoints == 0) then
			if (generateCP() ~= nil and HasSpell(generateCP()) == 1) then
				__, __, __, __, abilityCost = GetSpellInfoX(generateCP());
				if (abilityCost ~= nil and localEnergy >= abilityCost) then
					if (Cast(generateCP(), targetObj)) then
						if generateCP() ~= nil then
							debugText = "Cast "..generateCP();
						end
						return;
					end
				end
			end
		end
	end
else
	if (bot_ == 1) then
		--Eat
		if (IsTimeGood() == 1 and canEat == true) then	
			if IsSwimming() == 0 then
				if (IsEating() == 0 and localHealth < eatHealth) then
					if (IsMoving() == 1) then
						StopMoving();
						debugText = "Stop moving to eat (no target)";
						return;
					end
					-- this list only has food which increases HEALTH regen
					if type(foodList) == "string" then foodList = {foodList} end;
					for _,v in pairs(foodList) do
						if v == "" or v == nil or type(v) ~= "string" then
							v = "nil"
						end
						if (HasItem(v) == 1) then
							if (UseItem(v) == 1) then
								UpdateTimer(3);
								debugText = "Eat "..v.." (no target)";
								return;
							end
						else
							if type(bandageList) == "string" then bandageList = {bandagelist} end;
							for _,v in pairs (bandageList) do
								if v == "" or v == nil or  type(v) ~= "string" then
									v = "nil"
								end
								if HasItem(v) == 1 then
									if UseItem(v) == 1 then
										UpdateTimer(3);
										debugText = "Using "..v.." (no target)";
									end
								end
							end
						end
					end
				end
			end
		end
		--Stand if stopped eating
		if(localHealth >= 100 and IsStanding() == 0) then
			StopMoving();
			debugText = "Stand up at full hp (no target)";
			return;
		end
		--Stand after eating
		if(IsStanding() == 0  and localHealth >= eatHealth and IsEating() == 0) then
			StopMoving();
			debugText = "Stand up after eatingsitting and greater than "..eatHealth.."% hp (no target)";
			return;
		end
		--Stop even if we don't have food
		if(localHealth < eatHealth) then
			if (IsMoving() == 1) then
				StopMoving();
			end
			if (IsStanding() == 1) then
				SitOrStand();
			end
			debugText = "Stop moving below "..eatHealth.."% hp (no target)";
			return;
		end
		--Don't move we are eating
		if (IsEating() == 1) then
			if (IsMoving() == 1) then
				StopMoving();			
			end
			debugText = "Don't move while eating (no target)";
			return;
		end
		--Loot
		--if (Loot() == 1) then
		--	return;
		--end
		--Move
		if CheckPoisons() == true then
			debugText = "Applying Poisons (no target)";
			return
		end
		if IsTimeGood() == 1 and ApplyPoisons() == 1 and IsSwimming() == 0 then
			if Mount() == 1 then
				if (IsMoving() == 1) then
					StopMoving();			
				end
				debugText = "Mount up... YEE-HAA! (no target)"
				return;
			end
		end
		if (Navigate() == 1) then
			debugText = "Start Navigation (no target)";
			return;
		end
	end
end
--debugText = "Contemplating about life and existence..."