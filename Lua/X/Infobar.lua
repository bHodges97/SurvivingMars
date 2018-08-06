if FirstLoad then
	g_InfobarContextObj = false
end

DefineClass.Infobar = {
	__parents = { "XDialog" },
	PadHeight = 30,
}

local function SetContextRecursive(root, context)
	if IsKindOf(root, "XContextWindow") then
		root:SetContext(context)
	end
	for i,child in ipairs(root) do
		SetContextRecursive(child, context)
	end
end

function Infobar:Open(...)
	XDialog.Open(self, ...)
	
	self.idPad:SetMaxHeight(self.PadHeight)
	self.idPad:SetMinHeight(self.PadHeight)
	self:RecalculateMargins()
	
	local dlg = GetDialog("OnScreenHintDlg")
	if dlg then
		CreateGameTimeThread(dlg.RecalculateMargins, dlg)
	end
	
	--create context object & begin update thread
	if not g_InfobarContextObj then
		g_InfobarContextObj = InfobarObj:new()
	end
	self:CreateThread("UpdateThread", self.UpdateThreadFunc, self)
	
	--set contexts to each text field
	SetContextRecursive(self.idPad, g_InfobarContextObj)
end

function Infobar:Close(...)
	XDialog.Close(self, ...)
	
	local dlg = GetDialog("OnScreenHintDlg")
	if dlg then
		CreateGameTimeThread(dlg.RecalculateMargins, dlg)
	end
end

function Infobar:UpdateThreadFunc()
	--triggers UI update every 1 second
	while self.window_state ~= "destroying" do
		ObjModified(g_InfobarContextObj)
		Sleep(1000)
	end
end

function Infobar:RecalculateMargins()
	--This is temporarily and should be removed when implementing InGameInterface with new UI
	self:SetMargins(GetSafeMargins())
end

function UpdateInfobarVisibility()
	local igi = GetInGameInterface()
	if not igi then
		return
	end
	
	local visible = AccountStorage.Options.InfobarEnabled
	if visible then
		OpenDialog("Infobar", igi)
	else
		CloseDialog("Infobar")
	end
	
	local dlg = GetDialog("OnScreenHintDlg")
	if dlg then
		dlg:RecalculateMargins()
	end
end

function OnMsg.CityStart(igi)
	CreateGameTimeThread(UpdateInfobarVisibility)
end

function OnMsg.SafeAreaMarginsChanged()
	local infobar = GetDialog("Infobar")
	if infobar then
		infobar:RecalculateMargins()
	end
end

--UI text getters

DefineClass.InfobarObj = {
	__parents = { "PropertyObject" },
}

function InfobarObj:FmtFunding(n, colorized)
	return self:FmtRes(n, colorized)

	--note: temporarily commented out
	--formatting funding in the infobar happens in a specific manner:
	--0,1,2...,999, 1k,2k,3k,...,999k, 1M,2M,3M,...,999M, 1B,2B,3B,...
	--local abs_n = abs(n)
	--if abs_n >= 1000000000 then --billion (B)
	--	return T{9775, "<n>B", n = T{tostring(n / 1000000000)}}
	--elseif abs_n >= 1000000 then --million (M)
	--	return T{9776, "<n>M", n = T{tostring(n / 1000000)}}
	--elseif abs_n >= 1000 then --thousand (k)
	--	return T{9777, "<n>k", n = T{tostring(n / 1000)}}
	--else -- 0-999
	--	return T{9778, "<n>", n = T{tostring(n)}}
	--end
end

function InfobarObj:FmtRes(n, colorized)
	--formatting resource in the infobar happens in a specific manner:
	--0,1,2...,999, 1k,1.9k,2k,...,999k, 1M,1.9M,2M,...,999M, 1B,1.9B,2B,...
	local tnum
	local abs_n = abs(n)
	if abs_n >= 1000000000 then --billion (B)
		local div = 1000000000
		local value = n / div
		local rem = (n % div) / (div / 10)
		if rem > 0 then
			tnum = T{9807, --[[Infobar number formatting (billion)]] "<n>.<rem>B", n = T{tostring(value)}, rem = T{tostring(rem)}}
		else
			tnum = T{9775, --[[Infobar number formatting (billion)]] "<n>B", n = T{tostring(value)}}
		end
	elseif abs_n >= 1000000 then --million (M)
		local div = 1000000
		local value, rem = n / div, (n % div) / (div / 10)
		if rem > 0 then
			tnum = T{9808, --[[Infobar number formatting (million)]] "<n>.<rem>M", n = T{tostring(value)}, rem = T{tostring(rem)}}
		else
			tnum = T{9776, --[[Infobar number formatting (million)]] "<n>M", n = T{tostring(value)}}
		end
	elseif abs_n >= 1000 then --thousand (k)
		local div = 1000
		local value, rem = n / div, (n % div) / (div / 10)
		if rem > 0 then
			tnum = T{9809, --[[Infobar number formatting (thousand)]] "<n>.<rem>k", n = T{tostring(value)}, rem = T{tostring(rem)}}
		else
			tnum = T{9777, --[[Infobar number formatting (thousand)]] "<n>k", n = T{tostring(value)}}
		end
	else -- 0-999
		tnum = T{9778, --[[Infobar number formatting]] "<n>", n = T{tostring(n)}}
	end
	
	if colorized then
		if n >= 0 then
			return T{9779, "<green><tnum></green>", tnum = tnum}
		elseif n < 0 then
			return T{9780, "<red><tnum></red>", tnum = tnum}
		end
	else
		return tnum
	end
end

function InfobarObj:GetFundingText()
	local funding = ResourceOverviewObj:GetFunding()
	
	return T{9781, "$<funding>",
		funding = self:FmtFunding(funding),
	}
end

function InfobarObj:GetFundingRollover()
	return ResourceOverviewObj:GetFundingRollover()
end

function InfobarObj:GetResearchText()
	local estimate = ResourceOverviewObj:GetEstimatedRP()
	local progress = ResourceOverviewObj:GetResearchProgress()
	
	return T{9782, "<estimate><icon_Research_orig>  <progress><image UI/Icons/res_theoretical_research.tga>",
		estimate = self:FmtRes(estimate),
		progress = progress,
	}
end

function InfobarObj:GetResearchRollover()
	local rollover_items = ResourceOverviewObj:GetResearchRolloverItems()
	local current_research = T{10095, "Current Research<right><em><name></em>",
		name = function()
			local current_research = UICity and UICity:GetResearchInfo()
			return current_research and TechDef[current_research].display_name or T{6761, "None"}
		end,
	}
	table.insert(rollover_items, current_research)
	return table.concat(rollover_items, "<newline><left>")
end

function InfobarObj:GetGridResourcesText()
	local power = ResourceOverviewObj:GetPowerNumber() / const.ResourceScale
	local air = ResourceOverviewObj:GetAirNumber() / const.ResourceScale
	local water = ResourceOverviewObj:GetWaterNumber() / const.ResourceScale
	
	return T{9783, "<power><icon_Power_orig>  <air><icon_Air_orig>  <water><icon_Water_orig>",
		power = self:FmtRes(power, "colorized"),
		air = self:FmtRes(air, "colorized"),
		water = self:FmtRes(water, "colorized"),
	}
end

function InfobarObj:GetGridResourcesRollover()
	return ResourceOverviewObj:GetGridRollover()
end

local function StockpileHasResource(obj, resource)
	if type(obj.stockpiled_amount) == "table" then
		return (obj.stockpiled_amount[resource] or 0) > 0
	elseif obj.resource == resource then
		return (obj.stockpiled_amount or 0) > 0
	end
end

local function CycleObjects(list)
	if not list or not next(list) then
		return
	end

	--find the next object to select (or use the first one)
	local idx = SelectedObj and table.find(list, SelectedObj) or 0
	local idx = (idx % #list) + 1
	local next_obj = list[idx]
	
	ViewAndSelectObject(next_obj)
	XDestroyRolloverWindow()
end

local IsKindOf = IsKindOf
local query_filter = function(obj, resource)
		return (IsKindOf(obj, "ResourceStockpileBase") and StockpileHasResource(obj, resource)) or
		       (IsKindOf(obj, "Drone") and obj.resource == resource) or
		       (IsKindOf(obj, "CargoShuttle") and obj.carried_resource_type == resource) or
		       (IsKindOf(obj, "ResourceProducer") and obj.producers[resource] and obj.producers[resource].total_stockpiled > 0)
end

function InfobarObj:CycleResources(resource)
	--gather all objects
	local all_objs = MapGet(true, "ResourceStockpileBase", "CargoShuttle", "DroneBase", "Building", query_filter, resource)
	if not all_objs or not next(all_objs) then
		return
	end
	
	--this fixed the issue when one object is a child of another
	--later SelectionPropagate() returns the same obj and cycling stucks
	local unique_objs = { }
	for i,obj in ipairs(all_objs) do
		obj = SelectionPropagate(obj)
		if not unique_objs[obj] then
			table.insert(unique_objs, obj)
			unique_objs[obj] = #unique_objs
		end
	end
	
	CycleObjects(unique_objs)
end

function InfobarObj:GetMetalsText()
	local metals = ResourceOverviewObj:GetAvailableMetals() / const.ResourceScale
	return T{10096, "<metals><icon_Metals_orig>", metals = self:FmtRes(metals)}
end

function InfobarObj:GetConcreteText()
	local concrete = ResourceOverviewObj:GetAvailableConcrete() / const.ResourceScale
	return T{10097, "<concrete><icon_Concrete_orig>", concrete = self:FmtRes(concrete)}
end

function InfobarObj:GetFoodText()
	local food = ResourceOverviewObj:GetAvailableFood() / const.ResourceScale
	return T{10098, "<food><icon_Food_orig>", food = self:FmtRes(food)}
end

function InfobarObj:GetPreciousMetalsText()
	local precious_metals = ResourceOverviewObj:GetAvailablePreciousMetals() / const.ResourceScale
	return T{10099, "<precious_metals><icon_PreciousMetals_orig>", precious_metals = self:FmtRes(precious_metals)}
end

function InfobarObj:GetBasicResourcesRollover()
	return ResourceOverviewObj:GetBasicResourcesRollover()
end

function InfobarObj:GetPolymersText()
	local polymers = ResourceOverviewObj:GetAvailablePolymers() / const.ResourceScale
	return T{10100, "<polymers><icon_Polymers_orig>", polymers = self:FmtRes(polymers)}
end

function InfobarObj:GetElectronicsText()
	local electronics = ResourceOverviewObj:GetAvailableElectronics() / const.ResourceScale
	return T{10101, "<electronics><icon_Electronics_orig>", electronics = self:FmtRes(electronics)}
end

function InfobarObj:GetMachinePartsText()
	local machine_parts = ResourceOverviewObj:GetAvailableMachineParts() / const.ResourceScale
	return T{10102, "<machine_parts><icon_MachineParts_orig>", machine_parts = self:FmtRes(machine_parts)}
end

function InfobarObj:GetFuelText()
	local fuel = ResourceOverviewObj:GetAvailableFuel() / const.ResourceScale
	return T{10103, "<fuel><icon_Fuel_orig>", fuel = self:FmtRes(fuel)}
end

function InfobarObj:GetAdvancedResourcesRollover()
	return ResourceOverviewObj:GetAdvancedResourcesRollover()
end

function InfobarObj:CycleColonists(label)
	--gather the colonists
	local list = UICity.labels[label]
	
	CycleObjects(list)
end

function InfobarObj:CycleFreeHomes()
	local list = { }
	for _, home in ipairs(UICity.labels.Residence or empty_table) do
		if not home.destroyed and not home.children_only and home:GetFreeSpace() > 0 then
			table.insert(list, home)
		end
	end
	
	CycleObjects(list)
end

function InfobarObj:CycleFreeWorkplaces()
	local list = { }
	for _,workplace in ipairs(UICity.labels.Workplace or empty_table) do
		if not workplace.destroyed and not workplace.demolishing then
			if workplace.ui_working and workplace:GetFreeWorkSlots() > 0 then
				table.insert(list, workplace)
			end
		end
	end
	
	CycleObjects(list)
end

function InfobarObj:GetFreeHomes()
	local free_homes = ResourceOverviewObj:GetFreeLivingSpace()
	return T{10422, "<free_homes><icon_Home_orig>", free_homes = self:FmtRes(free_homes)}
end

function InfobarObj:GetHomeless()
	local homeless = ResourceOverviewObj:GetHomelessColonists()
	return T{10423, "<homeless><icon_Homeless_orig>", homeless = self:FmtRes(homeless)}
end

function InfobarObj:GetFreeWork()
	local free_work = ResourceOverviewObj:GetFreeWorkplaces()
	return T{10424, "<free_work><icon_Work_orig>", free_work = self:FmtRes(free_work)}
end

function InfobarObj:GetUnemployed()
	local unemployed = ResourceOverviewObj:GetUnemployedColonists()
	return T{10425, "<unemployed><icon_Unemployed_orig>", unemployed = self:FmtRes(unemployed)}
end

function InfobarObj:GetColonistCount()
	return ResourceOverviewObj:GetColonistCount()
end

function InfobarObj:GetColonistsRollover()
	return ResourceOverviewObj:GetColonistsRollover()
end