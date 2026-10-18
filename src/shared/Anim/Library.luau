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

-- Iron Oath (longsword). The right hand holds the sword; the waist twist sells every swing.
local guard = {
	RightShoulder = { x = 45, z = -5 },
	RightElbow = { x = 45 },
	LeftShoulder = { x = 15, z = -10 },
	LeftElbow = { x = 30 },
}

local function slash(duration, windupT, strikeT, windup, strike)
	return {
		duration = duration,
		keys = {
			{ t = 0, pose = guard },
			{ t = windupT, ease = "out", pose = windup },
			{ t = strikeT, ease = "in", pose = strike },
			{ t = duration, ease = "inout", pose = guard },
		},
	}
end

-- 1: horizontal cut, right to left.
Library.Slash1 = slash(0.4, 0.09, 0.17, {
	Root = { py = -0.3 },
	Waist = { y = 40 },
	RightShoulder = { x = 70, y = 30, z = 95 },
	RightElbow = { x = 50 },
	LeftShoulder = { x = 30, z = -30 },
	LeftHip = { x = 15 },
	RightHip = { x = -10 },
}, {
	Root = { py = -0.4 },
	Waist = { y = -45 },
	RightShoulder = { x = 95, y = -35, z = -25 },
	RightElbow = { x = 5 },
	LeftShoulder = { x = -20, z = -40 },
	LeftHip = { x = 25 },
	RightHip = { x = -20 },
})

-- 2: backhand diagonal, high left to low right.
Library.Slash2 = slash(0.4, 0.09, 0.18, {
	Waist = { y = -40, x = 5 },
	RightShoulder = { x = 150, z = -45 },
	RightElbow = { x = 60 },
	LeftShoulder = { x = 10, z = -20 },
}, {
	Root = { py = -0.5 },
	Waist = { y = 35, x = -15 },
	RightShoulder = { x = 45, z = 75 },
	RightElbow = { x = 10 },
	LeftShoulder = { x = -30, z = -50 },
	RightHip = { x = 25 },
	LeftHip = { x = -15 },
})

-- 3: low crouch into a rising cut.
Library.Slash3 = slash(0.42, 0.1, 0.2, {
	Root = { py = -0.9, x = -10 },
	Waist = { x = -20, y = 20 },
	RightShoulder = { x = -25, z = 40 },
	RightElbow = { x = 20 },
	LeftKnee = { x = -50 },
	RightKnee = { x = -50 },
	LeftHip = { x = 40 },
	RightHip = { x = 20 },
}, {
	Root = { py = 0.3, x = 5 },
	Waist = { x = 15, y = -10 },
	RightShoulder = { x = 175, z = 15 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = -40, z = -40 },
})

-- 4: stepping overhead cleave, both hands, the finisher of the string.
Library.Slash4 = slash(0.55, 0.16, 0.25, {
	Root = { x = 12 },
	Waist = { x = 20 },
	RightShoulder = { x = 185, z = 5 },
	RightElbow = { x = 30 },
	LeftShoulder = { x = 175, z = 15 },
	LeftElbow = { x = 30 },
	LeftHip = { x = 10 },
}, {
	Root = { x = -25, py = -0.8 },
	Waist = { x = -30 },
	RightShoulder = { x = 55 },
	RightElbow = { x = 5 },
	LeftShoulder = { x = 50, z = 15 },
	LeftElbow = { x = 10 },
	LeftHip = { x = 55 },
	LeftKnee = { x = -50 },
	RightHip = { x = -35 },
	RightKnee = { x = -20 },
})

Library.HeavyCharge = {
	duration = 0.3,
	hold = true,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.3,
			ease = "out",
			pose = {
				Root = { py = -0.5, x = 10 },
				Waist = { x = 18, y = 25 },
				RightShoulder = { x = 175, z = 35 },
				RightElbow = { x = 40 },
				LeftShoulder = { x = 150, z = 30 },
				LeftElbow = { x = 50 },
				LeftHip = { x = 30 },
				LeftKnee = { x = -30 },
				RightHip = { x = -20 },
			},
		},
	},
}

Library.HeavyRelease = {
	duration = 0.55,
	keys = {
		{
			t = 0,
			pose = {
				Root = { py = -0.5, x = 10 },
				Waist = { x = 18, y = 25 },
				RightShoulder = { x = 175, z = 35 },
				RightElbow = { x = 40 },
				LeftShoulder = { x = 150, z = 30 },
			},
		},
		{
			t = 0.12,
			ease = "in",
			pose = {
				Root = { x = -35, py = -1 },
				Waist = { x = -35, y = -20 },
				RightShoulder = { x = 40, z = -10 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 40, z = 20 },
				LeftHip = { x = 70 },
				LeftKnee = { x = -60 },
				RightHip = { x = -45 },
			},
		},
		{
			t = 0.4,
			pose = {
				Root = { x = -30, py = -0.9 },
				Waist = { x = -30 },
				RightShoulder = { x = 40 },
				LeftHip = { x = 65 },
				LeftKnee = { x = -55 },
				RightHip = { x = -40 },
			},
		},
		{ t = 0.55, ease = "inout", pose = guard },
	},
}

Library.Block = {
	duration = 0.1,
	hold = true,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.1,
			ease = "out",
			pose = {
				Root = { py = -0.45 },
				Waist = { x = -6, y = 15 },
				RightShoulder = { x = 85, z = -35 },
				RightElbow = { x = 75 },
				LeftShoulder = { x = 70, z = 40 },
				LeftElbow = { x = 85 },
				LeftHip = { x = 20 },
				RightHip = { x = 10 },
				LeftKnee = { x = -25 },
				RightKnee = { x = -25 },
			},
		},
	},
}

Library.BlockImpact = {
	duration = 0.22,
	keys = {
		{
			t = 0,
			pose = {
				Root = { py = -0.45, x = 12 },
				Waist = { x = 10, y = 15 },
				RightShoulder = { x = 95, z = -25 },
				RightElbow = { x = 80 },
				LeftShoulder = { x = 75, z = 40 },
				LeftElbow = { x = 85 },
				LeftKnee = { x = -30 },
				RightKnee = { x = -30 },
			},
		},
		{
			t = 0.22,
			ease = "out",
			pose = {
				Root = { py = -0.45 },
				Waist = { x = -6, y = 15 },
				RightShoulder = { x = 85, z = -35 },
				RightElbow = { x = 75 },
				LeftShoulder = { x = 70, z = 40 },
				LeftElbow = { x = 85 },
				LeftKnee = { x = -25 },
				RightKnee = { x = -25 },
			},
		},
	},
}

Library.Parry = {
	duration = 0.3,
	keys = {
		{ t = 0, pose = { RightShoulder = { x = 85, z = -35 }, RightElbow = { x = 75 } } },
		{
			t = 0.06,
			ease = "out",
			pose = {
				Waist = { y = -30 },
				RightShoulder = { x = 120, z = 70 },
				RightElbow = { x = 20 },
				LeftShoulder = { x = -20, z = -40 },
			},
		},
		{ t = 0.3, ease = "inout", pose = guard },
	},
}

Library.Parried = {
	duration = 0.6,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.08,
			ease = "out",
			pose = {
				Root = { x = 18, py = -0.3 },
				Waist = { x = 25 },
				Neck = { x = 15 },
				RightShoulder = { x = 175, z = 60 },
				RightElbow = { x = 10 },
				LeftShoulder = { x = 20, z = -60 },
				LeftHip = { x = -15 },
				RightHip = { x = 25 },
			},
		},
		{
			t = 0.45,
			pose = {
				Root = { x = 14, py = -0.3 },
				Waist = { x = 20 },
				RightShoulder = { x = 160, z = 55 },
				LeftShoulder = { x = 15, z = -55 },
			},
		},
		{ t = 0.6, ease = "inout", pose = guard },
	},
}

Library.HitFront = {
	duration = 0.35,
	keys = {
		{ t = 0, pose = {} },
		{
			t = 0.05,
			ease = "out",
			pose = {
				Root = { x = 16, py = -0.2 },
				Waist = { x = 18, y = 10 },
				Neck = { x = 25 },
				LeftShoulder = { x = -20, z = -45 },
				RightShoulder = { x = -10, z = 45 },
				LeftKnee = { x = -20 },
			},
		},
		{ t = 0.35, ease = "inout", pose = {} },
	},
}

Library.HitHeavy = {
	duration = 0.6,
	keys = {
		{ t = 0, pose = {} },
		{
			t = 0.06,
			ease = "out",
			pose = {
				Root = { x = 30, py = -0.4 },
				Waist = { x = 25, y = -15 },
				Neck = { x = 30 },
				LeftShoulder = { x = 40, z = -80 },
				RightShoulder = { x = 30, z = 80 },
				LeftHip = { x = 30 },
				LeftKnee = { x = -40 },
			},
		},
		{ t = 0.6, ease = "inout", pose = {} },
	},
}

Library.GuardBreak = {
	duration = 1.2,
	keys = {
		{ t = 0, pose = {} },
		{
			t = 0.1,
			ease = "out",
			pose = {
				Root = { x = 22, py = -0.7 },
				Waist = { x = 30 },
				Neck = { x = 30 },
				RightShoulder = { x = 160, z = 70 },
				LeftShoulder = { x = 140, z = -70 },
				LeftKnee = { x = -45 },
				RightKnee = { x = -30 },
			},
		},
		{
			t = 0.5,
			pose = {
				Root = { x = 14, z = 6, py = -0.6 },
				Waist = { x = 25, z = -8 },
				Neck = { x = 20, z = 10 },
				RightShoulder = { x = 30, z = 40 },
				LeftShoulder = { x = 20, z = -40 },
				LeftKnee = { x = -40 },
				RightKnee = { x = -35 },
			},
		},
		{
			t = 0.85,
			pose = {
				Root = { x = 14, z = -6, py = -0.6 },
				Waist = { x = 25, z = 8 },
				Neck = { x = 20, z = -10 },
				RightShoulder = { x = 30, z = 40 },
				LeftShoulder = { x = 20, z = -40 },
				LeftKnee = { x = -40 },
				RightKnee = { x = -35 },
			},
		},
		{ t = 1.2, ease = "inout", pose = {} },
	},
}

Library.GrabReach = {
	duration = 0.75,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.25,
			ease = "out",
			pose = {
				Root = { x = -20, py = -0.4 },
				Waist = { x = -15, y = -20 },
				LeftShoulder = { x = 95, z = 10 },
				LeftElbow = { x = 5 },
				RightShoulder = { x = 20, z = 30 },
				LeftHip = { x = 40 },
				LeftKnee = { x = -30 },
			},
		},
		{
			t = 0.4,
			ease = "in",
			pose = {
				Root = { x = -10, py = -0.3 },
				Waist = { x = 5, y = 40 },
				LeftShoulder = { x = 60, z = -40 },
				LeftElbow = { x = 40 },
				RightShoulder = { x = 70, z = 60 },
				RightElbow = { x = 30 },
			},
		},
		{ t = 0.75, ease = "inout", pose = guard },
	},
}

Library.Clash = {
	duration = 0.5,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.05,
			ease = "out",
			pose = {
				Root = { x = 12, py = -0.5 },
				Waist = { x = 15 },
				RightShoulder = { x = 110, z = -10 },
				RightElbow = { x = 60 },
				LeftShoulder = { x = 90, z = 20 },
				LeftElbow = { x = 70 },
				LeftKnee = { x = -35 },
				RightKnee = { x = -35 },
			},
		},
		{
			t = 0.35,
			pose = {
				Root = { x = 10, py = -0.5 },
				Waist = { x = 12 },
				RightShoulder = { x = 105, z = -10 },
				RightElbow = { x = 60 },
				LeftShoulder = { x = 85, z = 20 },
				LeftElbow = { x = 70 },
				LeftKnee = { x = -35 },
				RightKnee = { x = -35 },
			},
		},
		{ t = 0.5, ease = "inout", pose = guard },
	},
}

-- Iron Oath basic finisher: hilt strike, then one clean spinning cut.
Library.FinisherOath = {
	duration = 1.3,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.15,
			ease = "out",
			pose = {
				Waist = { y = 30 },
				RightShoulder = { x = 90, z = 20 },
				RightElbow = { x = 90 },
				LeftHip = { x = 30 },
			},
		},
		{
			t = 0.3,
			ease = "in",
			pose = {
				Waist = { y = -20, x = -10 },
				RightShoulder = { x = 100, z = -10 },
				RightElbow = { x = 20 },
				LeftHip = { x = 40 },
				LeftKnee = { x = -30 },
			},
		},
		{
			t = 0.6,
			ease = "out",
			pose = {
				Root = { py = -0.5 },
				Waist = { y = 80 },
				RightShoulder = { x = 70, y = 30, z = 100 },
				RightElbow = { x = 40 },
				LeftShoulder = { z = -60 },
			},
		},
		{
			t = 0.85,
			ease = "in",
			pose = {
				Root = { y = -360, py = -0.6 },
				Waist = { y = -60 },
				RightShoulder = { x = 95, y = -30, z = -20 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = -30, z = -60 },
			},
		},
		{
			t = 1.1,
			pose = {
				Root = { y = -360, py = -0.6 },
				Waist = { y = -50 },
				RightShoulder = { x = 90, z = -15 },
				LeftShoulder = { x = -30, z = -60 },
			},
		},
		{ t = 1.3, ease = "inout", pose = { Root = { y = -360 } } },
	},
}

Library.FinisherVictim = {
	duration = 1.6,
	hold = true,
	keys = {
		{ t = 0, pose = {} },
		{
			t = 0.3,
			ease = "out",
			pose = {
				Root = { x = 10, py = -0.8 },
				Waist = { x = 25 },
				Neck = { x = 30 },
				LeftKnee = { x = -70 },
				RightKnee = { x = -40 },
				LeftHip = { x = 40 },
				LeftShoulder = { x = 20, z = -20 },
				RightShoulder = { x = 20, z = 20 },
			},
		},
		{
			t = 1.6,
			pose = {
				Root = { x = 14, py = -1.6 },
				Waist = { x = 35 },
				Neck = { x = 40 },
				LeftKnee = { x = -110 },
				RightKnee = { x = -100 },
				LeftHip = { x = 80 },
				RightHip = { x = 60 },
				LeftShoulder = { x = 10, z = -10 },
				RightShoulder = { x = 10, z = 10 },
			},
		},
	},
}

return Library
