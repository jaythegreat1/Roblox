-- Keyframed action animations. Angles are degrees in each joint's own space:
-- x = pitch (positive swings a limb forward; on Root positive tips the body backward),
-- y = twist, z = roll (on Root positive tips the body to its left). py/pz are root offsets in studs.
-- Missing joints rest at 0. Keys are { t = seconds, ease = "in"|"out"|"inout"|"linear", pose = {...} }.
local Library = {}

local tuck = {
	LeftHip = { x = 110 },
	RightHip = { x = 110 },
	LeftKnee = { x = -130 },
	RightKnee = { x = -130 },
	LeftShoulder = { x = 60 },
	RightShoulder = { x = 60 },
	LeftElbow = { x = 90 },
	RightElbow = { x = 90 },
	Neck = { x = 30 },
	Waist = { x = -25 },
}

local function withRoot(base, root)
	local pose = table.clone(base)
	pose.Root = root
	return pose
end

Library.RollForward = {
	duration = 0.42,
	keys = {
		{ t = 0, pose = withRoot(tuck, { x = 0, py = -0.6 }) },
		{ t = 0.06, ease = "out", pose = withRoot(tuck, { x = -40, py = -1.4 }) },
		{ t = 0.32, ease = "inout", pose = withRoot(tuck, { x = -330, py = -1.6 }) },
		{
			t = 0.42,
			ease = "out",
			pose = {
				Root = { x = -360, py = -0.4 },
				LeftKnee = { x = -30 },
				RightKnee = { x = -30 },
				LeftHip = { x = 30 },
				RightHip = { x = 30 },
			},
		},
	},
}

Library.RollBack = {
	duration = 0.45,
	keys = {
		{
			t = 0,
			pose = {
				Root = { x = 0, py = -0.8 },
				LeftShoulder = { x = 160 },
				RightShoulder = { x = 160 },
				LeftKnee = { x = -50 },
				RightKnee = { x = -50 },
				LeftHip = { x = 40 },
				RightHip = { x = 40 },
			},
		},
		{
			t = 0.18,
			ease = "out",
			pose = {
				Root = { x = 170, py = 0.6 },
				LeftShoulder = { x = 180 },
				RightShoulder = { x = 180 },
				Waist = { x = 25 },
				Neck = { x = 25 },
			},
		},
		{
			t = 0.34,
			ease = "inout",
			pose = {
				Root = { x = 320, py = 0.2 },
				LeftHip = { x = 60 },
				RightHip = { x = 20 },
				LeftKnee = { x = -60 },
				LeftShoulder = { x = 90 },
				RightShoulder = { x = 90 },
			},
		},
		{
			t = 0.45,
			ease = "out",
			pose = {
				Root = { x = 360, py = -0.5 },
				LeftKnee = { x = -35 },
				RightKnee = { x = -35 },
				LeftHip = { x = 25 },
				RightHip = { x = 25 },
			},
		},
	},
}

local function cartwheel(sign)
	return {
		duration = 0.45,
		keys = {
			{ t = 0, pose = { Root = { z = 0, py = -0.5 }, LeftShoulder = { z = -80 }, RightShoulder = { z = 80 } } },
			{
				t = 0.08,
				ease = "out",
				pose = {
					Root = { z = 40 * sign, py = 0 },
					LeftShoulder = { z = -150 },
					RightShoulder = { z = 150 },
					LeftHip = { z = -35 },
					RightHip = { z = 35 },
				},
			},
			{
				t = 0.34,
				ease = "inout",
				pose = {
					Root = { z = 320 * sign, py = 0.4 },
					LeftShoulder = { z = -160 },
					RightShoulder = { z = 160 },
					LeftHip = { z = -45 },
					RightHip = { z = 45 },
				},
			},
			{
				t = 0.45,
				ease = "out",
				pose = { Root = { z = 360 * sign, py = -0.4 }, LeftKnee = { x = -25 }, RightKnee = { x = -25 } },
			},
		},
	}
end
Library.CartwheelLeft = cartwheel(1)
Library.CartwheelRight = cartwheel(-1)

local function flip(axis, sign, duration)
	local function root(a, py)
		return if axis == "x" then { x = a * sign, py = py } else { z = a * sign, py = py }
	end
	return {
		duration = duration,
		keys = {
			{ t = 0, pose = withRoot(tuck, root(0, 0)) },
			{ t = duration * 0.75, ease = "inout", pose = withRoot(tuck, root(320, 0.3)) },
			{
				t = duration,
				ease = "out",
				pose = {
					Root = root(360, 0),
					LeftShoulder = { z = -40 },
					RightShoulder = { z = 40 },
					LeftHip = { x = 20 },
					RightHip = { x = -10 },
				},
			},
		},
	}
end
Library.FlipFront = flip("x", -1, 0.5)
Library.FlipBack = flip("x", 1, 0.55)
Library.FlipLeft = flip("z", 1, 0.5)
Library.FlipRight = flip("z", -1, 0.5)

Library.LandRoll = {
	duration = 0.38,
	keys = {
		{ t = 0, pose = withRoot(tuck, { x = -20, py = -1.4 }) },
		{ t = 0.3, ease = "inout", pose = withRoot(tuck, { x = -340, py = -1.6 }) },
		{ t = 0.38, ease = "out", pose = { Root = { x = -360, py = -0.3 } } },
	},
}

Library.Dash = {
	duration = 0.3,
	keys = {
		{ t = 0, pose = { Root = { x = -10 } } },
		{
			t = 0.06,
			ease = "out",
			pose = {
				Root = { x = -32, py = -0.5 },
				Waist = { x = -10 },
				LeftShoulder = { x = -70, z = -20 },
				RightShoulder = { x = -70, z = 20 },
				LeftHip = { x = 50 },
				LeftKnee = { x = -40 },
				RightHip = { x = -40 },
				RightKnee = { x = -20 },
			},
		},
		{
			t = 0.24,
			pose = {
				Root = { x = -28, py = -0.5 },
				Waist = { x = -10 },
				LeftShoulder = { x = -75, z = -20 },
				RightShoulder = { x = -75, z = 20 },
				LeftHip = { x = 45 },
				LeftKnee = { x = -45 },
				RightHip = { x = -45 },
				RightKnee = { x = -25 },
			},
		},
		{ t = 0.3, ease = "out", pose = { Root = { x = -10 } } },
	},
}

Library.AirDash = {
	duration = 0.28,
	keys = {
		{ t = 0, pose = { Root = { x = -20 } } },
		{
			t = 0.06,
			ease = "out",
			pose = {
				Root = { x = -70 },
				LeftShoulder = { x = -60, z = -30 },
				RightShoulder = { x = -60, z = 30 },
				LeftHip = { x = -10 },
				RightHip = { x = -20 },
				LeftKnee = { x = -30 },
			},
		},
		{ t = 0.28, ease = "inout", pose = { Root = { x = -15 } } },
	},
}

Library.Slide = {
	duration = 0.8,
	keys = {
		{ t = 0, pose = { Root = { x = 0 } } },
		{
			t = 0.08,
			ease = "out",
			pose = {
				Root = { x = 35, py = -2.1 },
				Waist = { x = -20 },
				RightHip = { x = 85 },
				RightKnee = { x = -5 },
				LeftHip = { x = 20, z = -10 },
				LeftKnee = { x = -110 },
				LeftShoulder = { x = -30, z = -60 },
				RightShoulder = { x = 70 },
				RightElbow = { x = 40 },
			},
		},
		{
			t = 0.65,
			pose = {
				Root = { x = 32, py = -2 },
				Waist = { x = -18 },
				RightHip = { x = 80 },
				RightKnee = { x = -5 },
				LeftHip = { x = 20, z = -10 },
				LeftKnee = { x = -105 },
				LeftShoulder = { x = -30, z = -60 },
				RightShoulder = { x = 65 },
				RightElbow = { x = 40 },
			},
		},
		{ t = 0.8, ease = "inout", pose = { Root = { x = 0 } } },
	},
}

return Library
