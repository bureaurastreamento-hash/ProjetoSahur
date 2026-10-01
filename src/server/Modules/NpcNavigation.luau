--!strict
-- Caminhada de retorno, com caminhos recalculados. Nunca reposiciona o rig.
local PathfindingService = game:GetService("PathfindingService")
local Navigation = {}
export type State = { nextPlan: number, waypoints: { PathWaypoint }, index: number }
function Navigation.New(): State
	return { nextPlan = 0, waypoints = {}, index = 1 }
end
function Navigation.Home(humanoid: Humanoid, root: BasePart, home: Vector3, state: State)
	local now = os.clock()
	if now >= state.nextPlan then
		state.nextPlan = now + 2
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 5 })
		local ok = pcall(function() path:ComputeAsync(root.Position, home) end)
		state.waypoints = if ok and path.Status == Enum.PathStatus.Success then path:GetWaypoints() else {}
		state.index = math.min(2, #state.waypoints)
	end
	local waypoint = state.waypoints[state.index]
	if waypoint and (root.Position - waypoint.Position).Magnitude < 4 then
		state.index += 1
		waypoint = state.waypoints[state.index]
	end
	if waypoint and waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
	humanoid:MoveTo(if waypoint then waypoint.Position else home)
end
return Navigation
