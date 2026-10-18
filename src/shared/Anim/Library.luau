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

-- Grab: a two-handed lunge, a hoist, then a full spinning throw.
Library.GrabReach = {
	duration = 0.9,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.18,
			ease = "out",
			pose = {
				Root = { x = -30, py = -0.7 },
				Waist = { x = -20 },
				LeftShoulder = { x = 100, z = 15 },
				LeftElbow = { x = 0 },
				RightShoulder = { x = 100, z = -15 },
				RightElbow = { x = 0 },
				LeftHip = { x = 60 },
				LeftKnee = { x = -50 },
				RightHip = { x = -35 },
			},
		},
		{
			t = 0.35,
			ease = "out",
			pose = {
				Root = { x = 5, py = -0.4 },
				Waist = { x = 20 },
				LeftShoulder = { x = 160, z = 20 },
				LeftElbow = { x = 30 },
				RightShoulder = { x = 160, z = -20 },
				RightElbow = { x = 30 },
				LeftKnee = { x = -30 },
				RightKnee = { x = -30 },
			},
		},
		{
			t = 0.65,
			ease = "in",
			pose = {
				Root = { y = -300, py = -0.5 },
				Waist = { x = -25, y = -40 },
				LeftShoulder = { x = 70, z = -60 },
				LeftElbow = { x = 10 },
				RightShoulder = { x = 90, z = 70 },
				RightElbow = { x = 10 },
			},
		},
		{ t = 0.9, ease = "out", pose = { Root = { y = -360 } } },
	},
}

-- Being thrown: lifted, then tumbling head over heels.
Library.Thrown = {
	duration = 1,
	keys = {
		{ t = 0, pose = {} },
		{
			t = 0.3,
			ease = "out",
			pose = {
				Root = { x = 20, py = 0.5 },
				LeftShoulder = { x = 40, z = -90 },
				RightShoulder = { x = 40, z = 90 },
				LeftKnee = { x = -40 },
				RightKnee = { x = -60 },
			},
		},
		{
			t = 0.75,
			ease = "inout",
			pose = {
				Root = { x = 340 },
				LeftShoulder = { x = 60, z = -100 },
				RightShoulder = { x = 60, z = 100 },
				LeftHip = { x = 50 },
				RightHip = { x = 20 },
				LeftKnee = { x = -70 },
			},
		},
		{
			t = 1,
			ease = "out",
			pose = { Root = { x = 360, py = -0.8 }, LeftKnee = { x = -50 }, RightKnee = { x = -50 } },
		},
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

Library.Defeated = {
	duration = 0.9,
	hold = true,
	keys = {
		{ t = 0, pose = {} },
		{
			t = 0.25,
			ease = "out",
			pose = {
				Root = { x = 20, py = -0.6 },
				Waist = { x = 25 },
				Neck = { x = 30 },
				LeftKnee = { x = -60 },
				RightKnee = { x = -40 },
				LeftShoulder = { z = -30 },
				RightShoulder = { z = 30 },
			},
		},
		{
			t = 0.9,
			ease = "inout",
			pose = {
				Root = { x = 25, py = -2.1 },
				Waist = { x = 35 },
				Neck = { x = 40 },
				LeftHip = { x = 90 },
				RightHip = { x = 85 },
				LeftKnee = { x = -120 },
				RightKnee = { x = -115 },
				LeftShoulder = { x = 10, z = -15 },
				RightShoulder = { x = 10, z = 15 },
			},
		},
	},
}

--------------------------------------------------------------------------------
-- Kage (katana): fast draws from the left hip, a spin slash, and a delayed sheathe-cut.
local kageSheathed = {
	Waist = { y = -25 },
	RightShoulder = { x = 25, y = -30, z = -50 },
	RightElbow = { x = 70 },
	LeftShoulder = { x = 20, z = 15 },
	LeftElbow = { x = 60 },
}

Library.Kage1 = slash(0.3, 0.05, 0.12, kageSheathed, {
	Root = { py = -0.4 },
	Waist = { y = 45 },
	RightShoulder = { x = 90, y = 20, z = 95 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = -10, z = -30 },
	LeftHip = { x = 25 },
	RightHip = { x = -20 },
})
Library.Kage2 = slash(0.3, 0.05, 0.12, {
	Waist = { y = 45 },
	RightShoulder = { x = 90, z = 95 },
}, {
	Root = { py = -0.3 },
	Waist = { y = -45 },
	RightShoulder = { x = 95, y = -20, z = -35 },
	RightElbow = { x = 10 },
	RightHip = { x = 25 },
	LeftHip = { x = -20 },
})
Library.Kage3 = {
	duration = 0.38,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.06,
			ease = "out",
			pose = {
				Root = { py = -0.5 },
				Waist = { y = 30 },
				RightShoulder = { x = 80, z = 100 },
				RightElbow = { x = 5 },
			},
		},
		{
			t = 0.24,
			ease = "inout",
			pose = {
				Root = { y = -360, py = -0.5 },
				Waist = { y = -20 },
				RightShoulder = { x = 85, z = 100 },
				RightElbow = { x = 0 },
				LeftShoulder = { z = -80 },
			},
		},
		{
			t = 0.38,
			ease = "out",
			pose = { Root = { y = -360 }, RightShoulder = { x = 45, z = -5 }, RightElbow = { x = 45 } },
		},
	},
}
Library.Kage4 = slash(0.32, 0.07, 0.14, {
	Root = { py = -0.9 },
	Waist = { x = -15, y = 25 },
	RightShoulder = { x = -20, z = 50 },
	LeftKnee = { x = -60 },
	RightKnee = { x = -50 },
	LeftHip = { x = 45 },
}, {
	Root = { py = 0.4 },
	Waist = { x = 15 },
	RightShoulder = { x = 175, z = 25 },
	RightElbow = { x = 0 },
})
Library.Kage5 = {
	duration = 0.55,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.1,
			ease = "out",
			pose = {
				Root = { py = -0.5 },
				Waist = { y = 50 },
				RightShoulder = { x = 90, z = 100 },
				RightElbow = { x = 0 },
			},
		},
		{
			t = 0.25,
			ease = "inout",
			pose = {
				Root = { py = -0.6 },
				Waist = { y = -30 },
				RightShoulder = { x = 25, y = -30, z = -50 },
				RightElbow = { x = 70 },
				LeftShoulder = { x = 20, z = 15 },
				LeftElbow = { x = 60 },
			},
		},
		{ t = 0.55, pose = kageSheathed },
	},
}
Library.KageCharge = {
	duration = 0.3,
	hold = true,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.3,
			ease = "out",
			pose = {
				Root = { py = -0.9, x = -10 },
				Waist = { y = -40, x = -10 },
				RightShoulder = { x = 25, y = -30, z = -55 },
				RightElbow = { x = 75 },
				LeftShoulder = { x = 25, z = 15 },
				LeftElbow = { x = 65 },
				LeftHip = { x = 55 },
				LeftKnee = { x = -60 },
				RightHip = { x = -35 },
				RightKnee = { x = -30 },
			},
		},
	},
}
Library.KageFlash = {
	duration = 0.6,
	keys = {
		{
			t = 0,
			pose = {
				Root = { py = -0.9, x = -10 },
				Waist = { y = -40 },
				RightShoulder = { x = 25, y = -30, z = -55 },
				RightElbow = { x = 75 },
			},
		},
		{
			t = 0.08,
			ease = "out",
			pose = {
				Root = { x = -35, py = -1 },
				Waist = { y = 55 },
				RightShoulder = { x = 90, z = 110 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = -40, z = -30 },
				LeftHip = { x = 60 },
				LeftKnee = { x = -50 },
				RightHip = { x = -50 },
			},
		},
		{
			t = 0.4,
			pose = {
				Root = { x = -25, py = -0.9 },
				Waist = { y = 55 },
				RightShoulder = { x = 85, z = 110 },
				LeftShoulder = { x = -40, z = -30 },
				LeftHip = { x = 55 },
				LeftKnee = { x = -45 },
				RightHip = { x = -45 },
			},
		},
		{ t = 0.6, ease = "inout", pose = kageSheathed },
	},
}

--------------------------------------------------------------------------------
-- Twin Fangs (dual daggers): alternating stabs, a cartwheel, a spinning top, a backflip kick.
local fangGuard = {
	RightShoulder = { x = 50, z = 15 },
	RightElbow = { x = 70 },
	LeftShoulder = { x = 50, z = -15 },
	LeftElbow = { x = 70 },
	Root = { py = -0.3 },
	LeftKnee = { x = -20 },
	RightKnee = { x = -20 },
}
local function fang(duration, strikeT, strike)
	return {
		duration = duration,
		keys = {
			{ t = 0, pose = fangGuard },
			{ t = strikeT, ease = "out", pose = strike },
			{ t = duration, ease = "inout", pose = fangGuard },
		},
	}
end
Library.Fang1 = fang(0.22, 0.07, {
	Root = { x = -10, py = -0.3 },
	Waist = { y = -25 },
	RightShoulder = { x = 95, z = -5 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = 30, z = -20 },
	LeftElbow = { x = 90 },
	LeftHip = { x = 30 },
})
Library.Fang2 = fang(0.22, 0.07, {
	Root = { x = -10, py = -0.3 },
	Waist = { y = 25 },
	LeftShoulder = { x = 95, z = 5 },
	LeftElbow = { x = 0 },
	RightShoulder = { x = 30, z = 20 },
	RightElbow = { x = 90 },
	RightHip = { x = 30 },
})
Library.Fang3 = {
	duration = 0.32,
	keys = {
		{ t = 0, pose = fangGuard },
		{
			t = 0.22,
			ease = "inout",
			pose = {
				Root = { z = 330, py = 0.6 },
				LeftShoulder = { z = -160 },
				RightShoulder = { z = 160 },
				LeftHip = { z = -45 },
				RightHip = { z = 45 },
			},
		},
		{
			t = 0.32,
			ease = "out",
			pose = { Root = { z = 360 }, RightShoulder = { x = 50, z = 15 }, LeftShoulder = { x = 50, z = -15 } },
		},
	},
}
Library.Fang4 = {
	duration = 0.34,
	keys = {
		{ t = 0, pose = fangGuard },
		{
			t = 0.28,
			ease = "inout",
			pose = {
				Root = { y = -720, py = -0.4 },
				LeftShoulder = { x = 80, z = -90 },
				RightShoulder = { x = 80, z = 90 },
				LeftElbow = { x = 0 },
				RightElbow = { x = 0 },
			},
		},
		{
			t = 0.34,
			ease = "out",
			pose = { Root = { y = -720 }, RightShoulder = { x = 50, z = 15 }, LeftShoulder = { x = 50, z = -15 } },
		},
	},
}
Library.Fang5 = fang(0.26, 0.1, {
	Root = { py = 0.3 },
	Waist = { x = 15 },
	RightShoulder = { x = 170, z = 15 },
	LeftShoulder = { x = 170, z = -15 },
	RightElbow = { x = 0 },
	LeftElbow = { x = 0 },
})
Library.Fang6 = {
	duration = 0.45,
	keys = {
		{ t = 0, pose = fangGuard },
		{
			t = 0.12,
			ease = "out",
			pose = {
				Root = { x = 100, py = 1 },
				RightHip = { x = 120 },
				RightKnee = { x = 0 },
				LeftKnee = { x = -60 },
				LeftShoulder = { z = -100 },
				RightShoulder = { z = 100 },
			},
		},
		{
			t = 0.36,
			ease = "inout",
			pose = {
				Root = { x = 330, py = 0.5 },
				RightHip = { x = 40 },
				LeftKnee = { x = -60 },
				RightKnee = { x = -60 },
			},
		},
		{
			t = 0.45,
			ease = "out",
			pose = { Root = { x = 360 }, RightShoulder = { x = 50, z = 15 }, LeftShoulder = { x = 50, z = -15 } },
		},
	},
}
Library.FangCharge = {
	duration = 0.3,
	hold = true,
	keys = {
		{ t = 0, pose = fangGuard },
		{
			t = 0.3,
			ease = "out",
			pose = {
				Root = { py = -0.5 },
				Waist = { x = 15, y = 10 },
				RightShoulder = { x = -30, z = 50 },
				LeftShoulder = { x = -30, z = -50 },
				RightElbow = { x = 60 },
				LeftElbow = { x = 60 },
				LeftHip = { x = 30 },
				LeftKnee = { x = -40 },
			},
		},
	},
}
Library.FangToss = {
	duration = 0.7,
	keys = {
		{ t = 0, pose = { RightShoulder = { x = -30, z = 50 }, LeftShoulder = { x = -30, z = -50 } } },
		{
			t = 0.1,
			ease = "out",
			pose = {
				Root = { x = -15 },
				Waist = { x = -15 },
				RightShoulder = { x = 110, z = 10 },
				LeftShoulder = { x = 110, z = -10 },
				RightElbow = { x = 0 },
				LeftElbow = { x = 0 },
				LeftHip = { x = 40 },
				LeftKnee = { x = -35 },
			},
		},
		{
			t = 0.55,
			pose = {
				Root = { x = -5 },
				RightShoulder = { x = 90, z = 20 },
				LeftShoulder = { x = 90, z = -20 },
				RightElbow = { x = 20 },
				LeftElbow = { x = 20 },
			},
		},
		{ t = 0.7, ease = "inout", pose = fangGuard },
	},
}

--------------------------------------------------------------------------------
-- Titan's Maw (greatsword): slow, huge, two-handed.
local titanGuard = {
	Root = { py = -0.3 },
	Waist = { y = 20 },
	RightShoulder = { x = 40, z = 10 },
	RightElbow = { x = 50 },
	LeftShoulder = { x = 50, z = 35 },
	LeftElbow = { x = 60 },
	LeftHip = { x = 15 },
	RightHip = { x = -10 },
}
Library.Titan1 = {
	duration = 0.65,
	keys = {
		{ t = 0, pose = titanGuard },
		{
			t = 0.2,
			ease = "out",
			pose = {
				Root = { x = 15 },
				Waist = { x = 20 },
				RightShoulder = { x = 190 },
				RightElbow = { x = 30 },
				LeftShoulder = { x = 180, z = 20 },
				LeftElbow = { x = 30 },
			},
		},
		{
			t = 0.32,
			ease = "in",
			pose = {
				Root = { x = -30, py = -1 },
				Waist = { x = -35 },
				RightShoulder = { x = 50 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 50, z = 20 },
				LeftElbow = { x = 0 },
				LeftHip = { x = 60 },
				LeftKnee = { x = -60 },
				RightHip = { x = -40 },
			},
		},
		{ t = 0.65, ease = "inout", pose = titanGuard },
	},
}
Library.Titan2 = {
	duration = 0.75,
	keys = {
		{ t = 0, pose = titanGuard },
		{
			t = 0.18,
			ease = "out",
			pose = {
				Root = { py = -0.6 },
				Waist = { y = 70 },
				RightShoulder = { x = 80, z = 100 },
				LeftShoulder = { x = 70, z = 60 },
			},
		},
		{
			t = 0.4,
			ease = "inout",
			pose = {
				Root = { y = -270, py = -0.7 },
				Waist = { y = -40 },
				RightShoulder = { x = 85, z = 100 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 80, z = 70 },
			},
		},
		{
			t = 0.75,
			ease = "inout",
			pose = {
				Root = { y = -360 },
				Waist = { y = 20 },
				RightShoulder = { x = 40, z = 10 },
				RightElbow = { x = 50 },
				LeftShoulder = { x = 50, z = 35 },
			},
		},
	},
}
Library.Titan3 = {
	duration = 0.9,
	keys = {
		{ t = 0, pose = titanGuard },
		{
			t = 0.25,
			ease = "out",
			pose = {
				Root = { y = -200, py = 1 },
				Waist = { x = 20 },
				RightShoulder = { x = 190 },
				LeftShoulder = { x = 180 },
				LeftKnee = { x = -60 },
				RightKnee = { x = -60 },
			},
		},
		{
			t = 0.42,
			ease = "in",
			pose = {
				Root = { y = -360, x = -30, py = -1.4 },
				Waist = { x = -40 },
				RightShoulder = { x = 40 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 40 },
				LeftHip = { x = 70 },
				LeftKnee = { x = -70 },
				RightHip = { x = -40 },
			},
		},
		{
			t = 0.7,
			pose = {
				Root = { y = -360, x = -25, py = -1.3 },
				Waist = { x = -35 },
				RightShoulder = { x = 40 },
				LeftShoulder = { x = 40 },
				LeftHip = { x = 65 },
				LeftKnee = { x = -65 },
			},
		},
		{ t = 0.9, ease = "inout", pose = { Root = { y = -360 } } },
	},
}
Library.TitanCharge = {
	duration = 0.35,
	hold = true,
	keys = {
		{ t = 0, pose = titanGuard },
		{
			t = 0.35,
			ease = "out",
			pose = {
				Root = { py = -0.8 },
				Waist = { y = 60, x = 10 },
				RightShoulder = { x = 120, z = 100 },
				RightElbow = { x = 30 },
				LeftShoulder = { x = 100, z = 70 },
				LeftKnee = { x = -45 },
				RightKnee = { x = -45 },
				LeftHip = { x = 30 },
			},
		},
	},
}
Library.TitanCyclone = {
	duration = 1.1,
	keys = {
		{ t = 0, pose = { Root = { py = -0.8 }, Waist = { y = 60 }, RightShoulder = { x = 120, z = 100 } } },
		{
			t = 0.85,
			ease = "linear",
			pose = {
				Root = { y = -1080, py = -0.6 },
				RightShoulder = { x = 85, z = 100 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 80, z = -80 },
			},
		},
		{
			t = 0.95,
			ease = "out",
			pose = {
				Root = { y = -1080, x = -25, py = -1.2 },
				Waist = { x = -30 },
				RightShoulder = { x = 40 },
				LeftShoulder = { x = 40 },
			},
		},
		{ t = 1.1, ease = "inout", pose = { Root = { y = -1080 } } },
	},
}

--------------------------------------------------------------------------------
-- Fleuret (rapier): en garde, jabs, a pirouette thrust and a drilling lunge.
local enGarde = {
	Root = { py = -0.4 },
	Waist = { y = -35 },
	RightShoulder = { x = 70, z = -10 },
	RightElbow = { x = 30 },
	LeftShoulder = { x = -10, z = -100 },
	LeftElbow = { x = 90 },
	LeftHip = { x = -20 },
	RightHip = { x = 30 },
	RightKnee = { x = -30 },
}
local function thrust(duration, strikeT, strike)
	return {
		duration = duration,
		keys = {
			{ t = 0, pose = enGarde },
			{ t = strikeT, ease = "out", pose = strike },
			{ t = duration, ease = "inout", pose = enGarde },
		},
	}
end
local lungeLegs = { RightHip = { x = 70 }, RightKnee = { x = -60 }, LeftHip = { x = -40 }, LeftKnee = { x = 0 } }
Library.Fleuret1 = thrust(0.24, 0.07, {
	Root = { x = -12, py = -0.5 },
	Waist = { y = -50 },
	RightShoulder = { x = 92, z = -5 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = -10, z = -100 },
	LeftElbow = { x = 90 },
})
Library.Fleuret2 = {
	duration = 0.28,
	keys = {
		{ t = 0, pose = enGarde },
		{ t = 0.06, ease = "out", pose = { Waist = { y = -50 }, RightShoulder = { x = 92 }, RightElbow = { x = 0 } } },
		{ t = 0.1, pose = { Waist = { y = -40 }, RightShoulder = { x = 75 }, RightElbow = { x = 40 } } },
		{
			t = 0.14,
			ease = "out",
			pose = { Root = { x = -12 }, Waist = { y = -55 }, RightShoulder = { x = 94 }, RightElbow = { x = 0 } },
		},
		{ t = 0.28, ease = "inout", pose = enGarde },
	},
}
Library.Fleuret3 = {
	duration = 0.36,
	keys = {
		{ t = 0, pose = enGarde },
		{
			t = 0.18,
			ease = "inout",
			pose = {
				Root = { y = -360, py = -0.3 },
				Waist = { y = 20 },
				RightShoulder = { x = 70, z = 60 },
				LeftShoulder = { z = -80 },
			},
		},
		{
			t = 0.24,
			ease = "out",
			pose = {
				Root = { y = -360, x = -15, py = -0.6 },
				Waist = { y = -50 },
				RightShoulder = { x = 92 },
				RightElbow = { x = 0 },
				RightHip = { x = 50 },
				RightKnee = { x = -50 },
			},
		},
		{
			t = 0.36,
			ease = "inout",
			pose = {
				Root = { y = -360, py = -0.4 },
				Waist = { y = -35 },
				RightShoulder = { x = 70, z = -10 },
				RightElbow = { x = 30 },
			},
		},
	},
}
local lowLunge = {
	Root = { x = -20, py = -1.1 },
	Waist = { y = -50 },
	RightShoulder = { x = 88 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = -30, z = -60 },
}
for k, v in lungeLegs do
	lowLunge[k] = v
end
Library.Fleuret4 = thrust(0.32, 0.12, lowLunge)
Library.Fleuret5 = thrust(
	0.32,
	0.1,
	{ Root = { py = 0.2 }, Waist = { y = -30, x = 10 }, RightShoulder = { x = 155, z = -10 }, RightElbow = { x = 0 } }
)
Library.FleuretCharge = {
	duration = 0.3,
	hold = true,
	keys = {
		{ t = 0, pose = enGarde },
		{
			t = 0.3,
			ease = "out",
			pose = {
				Root = { py = -0.8, x = 10 },
				Waist = { y = -55 },
				RightShoulder = { x = 70, z = 20 },
				RightElbow = { x = 90 },
				LeftShoulder = { x = -10, z = -110 },
				LeftElbow = { x = 90 },
				RightHip = { x = 45 },
				RightKnee = { x = -60 },
				LeftKnee = { x = -40 },
			},
		},
	},
}
local fleche = {
	Root = { x = -35, z = -720, py = -0.8 },
	Waist = { y = -40 },
	RightShoulder = { x = 90 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = -40, z = -40 },
}
for k, v in lungeLegs do
	fleche[k] = v
end
Library.FleuretFleche = {
	duration = 0.6,
	keys = {
		{
			t = 0,
			pose = {
				Root = { py = -0.8, x = 10 },
				Waist = { y = -55 },
				RightShoulder = { x = 70, z = 20 },
				RightElbow = { x = 90 },
			},
		},
		{ t = 0.25, ease = "linear", pose = fleche },
		{
			t = 0.4,
			pose = {
				Root = { x = -30, z = -720, py = -0.9 },
				Waist = { y = -45 },
				RightShoulder = { x = 90 },
				RightHip = { x = 65 },
				RightKnee = { x = -55 },
				LeftHip = { x = -40 },
			},
		},
		{
			t = 0.6,
			ease = "inout",
			pose = {
				Root = { z = -720, py = -0.4 },
				Waist = { y = -35 },
				RightShoulder = { x = 70, z = -10 },
				RightElbow = { x = 30 },
			},
		},
	},
}

--------------------------------------------------------------------------------
-- Sirocco (scimitar): every move is a spin.
local dance = {
	Root = { py = -0.2 },
	Waist = { y = 15 },
	RightShoulder = { x = 30, z = 60 },
	RightElbow = { x = 30 },
	LeftShoulder = { x = 20, z = -60 },
	LeftElbow = { x = 30 },
}
local function spin(duration, turns, py, armZ, extra)
	local strike = {
		Root = { y = -360 * turns, py = py },
		RightShoulder = { x = 85, z = armZ },
		RightElbow = { x = 0 },
		LeftShoulder = { x = 40, z = -80 },
	}
	for k, v in extra or {} do
		strike[k] = v
	end
	return {
		duration = duration,
		keys = {
			{ t = 0, pose = dance },
			{ t = duration * 0.7, ease = "inout", pose = strike },
			{
				t = duration,
				ease = "out",
				pose = {
					Root = { y = -360 * turns },
					Waist = { y = 15 },
					RightShoulder = { x = 30, z = 60 },
					LeftShoulder = { x = 20, z = -60 },
				},
			},
		},
	}
end
Library.Sirocco1 = spin(0.34, 1, -0.3, 100)
Library.Sirocco2 = spin(0.34, -1, -0.3, -20)
Library.Sirocco3 = spin(0.46, 2, 1.4, 100, { LeftKnee = { x = -70 }, RightKnee = { x = -50 }, LeftHip = { x = 40 } })
Library.Sirocco4 = spin(
	0.44,
	1,
	-1.3,
	110,
	{ LeftHip = { x = 80, z = -30 }, LeftKnee = { x = -100 }, RightHip = { x = 10, z = 40 }, RightKnee = { x = -20 } }
)
Library.SiroccoCharge = {
	duration = 0.3,
	hold = true,
	keys = {
		{ t = 0, pose = dance },
		{
			t = 0.3,
			ease = "out",
			pose = {
				Root = { py = -0.5 },
				Waist = { y = 70 },
				RightShoulder = { x = 60, z = 110 },
				LeftShoulder = { x = 60, z = -40 },
				LeftKnee = { x = -30 },
				RightKnee = { x = -30 },
			},
		},
	},
}
Library.SiroccoWaltz = {
	duration = 1.0,
	keys = {
		{ t = 0, pose = { Root = { py = -0.5 }, Waist = { y = 70 }, RightShoulder = { x = 60, z = 110 } } },
		{
			t = 0.85,
			ease = "linear",
			pose = {
				Root = { y = -1440, py = -0.2 },
				Waist = { y = 0 },
				RightShoulder = { x = 85, z = 100 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 60, z = -100 },
			},
		},
		{
			t = 1.0,
			ease = "out",
			pose = {
				Root = { y = -1440 },
				Waist = { y = 15 },
				RightShoulder = { x = 30, z = 60 },
				LeftShoulder = { x = 20, z = -60 },
			},
		},
	},
}

--------------------------------------------------------------------------------
-- Echoes: every superpower has its own move.
local function held(duration, holdFrom, pose, settle)
	return {
		duration = duration,
		keys = {
			{ t = 0, pose = guard },
			{ t = settle or 0.15, ease = "out", pose = pose },
			{ t = holdFrom, pose = pose },
			{ t = duration, ease = "inout", pose = guard },
		},
	}
end

-- Ember Dash: a low lunge with the sword dragged behind, ending in a full spin.
Library.EchoEmberDash = {
	duration = 0.6,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.07,
			ease = "out",
			pose = {
				Root = { x = -28, py = -1.2 },
				Waist = { x = -15 },
				RightShoulder = { x = -45, z = 25 },
				RightElbow = { x = 10 },
				LeftShoulder = { x = 60, z = -10 },
				LeftHip = { x = 65 },
				LeftKnee = { x = -60 },
				RightHip = { x = -35 },
			},
		},
		{
			t = 0.3,
			pose = {
				Root = { x = -28, py = -1.2 },
				Waist = { x = -15 },
				RightShoulder = { x = -45, z = 25 },
				LeftShoulder = { x = 60, z = -10 },
				LeftHip = { x = 65 },
				LeftKnee = { x = -60 },
				RightHip = { x = -35 },
			},
		},
		{
			t = 0.52,
			ease = "inout",
			pose = {
				Root = { y = -360, py = -0.6 },
				RightShoulder = { x = 85, z = 100 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 40, z = -80 },
			},
		},
		{ t = 0.6, ease = "out", pose = { Root = { y = -360 } } },
	},
}

-- Flame Fang: a wide horizontal slash with a full body twist.
Library.EchoFlameFang = {
	duration = 0.5,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.12,
			ease = "out",
			pose = {
				Root = { py = -0.5 },
				Waist = { y = 70 },
				RightShoulder = { x = 80, z = 115 },
				RightElbow = { x = 20 },
				LeftShoulder = { x = 40, z = -20 },
				LeftHip = { x = 25 },
			},
		},
		{
			t = 0.24,
			ease = "in",
			pose = {
				Root = { y = -200, py = -0.6 },
				Waist = { y = -50 },
				RightShoulder = { x = 95, z = -20 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = -20, z = -60 },
				RightHip = { x = 30 },
			},
		},
		{ t = 0.42, ease = "out", pose = { Root = { y = -360, py = -0.3 }, RightShoulder = { x = 60, z = 30 } } },
		{ t = 0.5, ease = "inout", pose = { Root = { y = -360 } } },
	},
}

-- Blaze Spiral: a corkscrew rising slash, two full spins.
Library.EchoBlazeSpiral = {
	duration = 0.65,
	keys = {
		{
			t = 0,
			pose = {
				Root = { py = -1 },
				LeftKnee = { x = -60 },
				RightKnee = { x = -60 },
				LeftHip = { x = 40 },
				RightHip = { x = 40 },
				RightShoulder = { x = -20, z = 60 },
			},
		},
		{
			t = 0.5,
			ease = "linear",
			pose = {
				Root = { y = -720, py = 1.6 },
				RightShoulder = { x = 175, z = 20 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 30, z = -110 },
				LeftKnee = { x = -40 },
				RightHip = { x = 20 },
			},
		},
		{ t = 0.65, ease = "out", pose = { Root = { y = -720 }, RightShoulder = { x = 60 } } },
	},
}

-- Inferno Cage: both hands drive the sword into the ground.
Library.EchoInfernoCage = {
	duration = 0.75,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.15,
			ease = "out",
			pose = {
				Root = { py = 0.3, x = 8 },
				RightShoulder = { x = 185 },
				RightElbow = { x = 10 },
				LeftShoulder = { x = 175 },
				LeftElbow = { x = 15 },
				Neck = { x = -15 },
			},
		},
		{
			t = 0.3,
			ease = "in",
			pose = {
				Root = { x = -30, py = -1.4 },
				Waist = { x = -30 },
				RightShoulder = { x = 60 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 60, z = 10 },
				LeftElbow = { x = 0 },
				LeftHip = { x = 70 },
				LeftKnee = { x = -80 },
				RightHip = { x = 10 },
				RightKnee = { x = -70 },
			},
		},
		{
			t = 0.6,
			pose = {
				Root = { x = -28, py = -1.3 },
				Waist = { x = -28 },
				RightShoulder = { x = 62 },
				LeftShoulder = { x = 62, z = 10 },
				LeftHip = { x = 70 },
				LeftKnee = { x = -80 },
				RightKnee = { x = -70 },
			},
		},
		{ t = 0.75, ease = "inout", pose = guard },
	},
}

-- Solar Flare: a jumping overhand throw.
Library.EchoSolarFlare = {
	duration = 0.65,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.18,
			ease = "out",
			pose = {
				Root = { py = 1, x = 18 },
				Waist = { x = 15, y = 30 },
				RightShoulder = { x = 205, z = 15 },
				RightElbow = { x = 95 },
				LeftShoulder = { x = 100, z = -20 },
				LeftHip = { x = 50 },
				LeftKnee = { x = -70 },
				RightKnee = { x = -30 },
			},
		},
		{
			t = 0.32,
			ease = "in",
			pose = {
				Root = { py = 0.8, x = -22 },
				Waist = { x = -25, y = -25 },
				RightShoulder = { x = 70 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = -20, z = -30 },
				LeftHip = { x = 30 },
				RightHip = { x = -20 },
			},
		},
		{ t = 0.65, ease = "inout", pose = guard },
	},
}

-- Meteor Brand: the sword raised to the sky.
Library.EchoMeteorBrand = held(0.85, 0.7, {
	Root = { x = 10 },
	Waist = { x = 8 },
	RightShoulder = { x = 180 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = 50, z = -50 },
	LeftElbow = { x = 30 },
	Neck = { x = -30 },
	LeftHip = { x = 15 },
	RightHip = { x = -10 },
}, 0.22)

-- Phoenix Descent: wings unfold for the climb, then a screaming dive.
Library.EchoPhoenixRise = {
	duration = 0.3,
	hold = true,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.3,
			ease = "out",
			pose = {
				Root = { x = 15 },
				LeftShoulder = { x = 25, z = -105 },
				RightShoulder = { x = 25, z = 105 },
				LeftElbow = { x = 10 },
				RightElbow = { x = 10 },
				Neck = { x = -25 },
				LeftHip = { x = -10 },
				RightHip = { x = -10 },
				LeftKnee = { x = -20 },
				RightKnee = { x = -20 },
			},
		},
	},
}
Library.EchoPhoenixDive = {
	duration = 0.55,
	keys = {
		{
			t = 0,
			ease = "out",
			pose = {
				Root = { x = -75 },
				RightShoulder = { x = 175 },
				LeftShoulder = { x = 170 },
				Neck = { x = -30 },
				LeftHip = { x = -15 },
				RightHip = { x = -15 },
			},
		},
		{
			t = 0.36,
			pose = {
				Root = { x = -80 },
				RightShoulder = { x = 175 },
				LeftShoulder = { x = 170 },
				Neck = { x = -30 },
			},
		},
		{
			t = 0.45,
			ease = "in",
			pose = {
				Root = { x = -25, py = -1.5 },
				Waist = { x = -20 },
				RightShoulder = { x = 55 },
				LeftShoulder = { x = 50 },
				LeftHip = { x = 80 },
				LeftKnee = { x = -100 },
				RightHip = { x = 20 },
				RightKnee = { x = -90 },
			},
		},
		{ t = 0.55, ease = "inout", pose = guard },
	},
}

-- Flash Step: a crouched iai cut as you vanish.
Library.EchoFlashStep = slash(0.38, 0.06, 0.16, {
	Root = { py = -0.9, x = -15 },
	Waist = { y = 35 },
	RightShoulder = { x = -30, z = 30 },
	RightElbow = { x = 20 },
	LeftShoulder = { x = 20, z = -20 },
	LeftHip = { x = 50 },
	LeftKnee = { x = -60 },
}, {
	Root = { py = -0.5, x = -10 },
	Waist = { y = -40 },
	RightShoulder = { x = 95, z = -40 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = -30, z = -40 },
	LeftHip = { x = 40 },
	RightHip = { x = -20 },
})

-- Volt Lance: a javelin throw.
Library.EchoVoltLance = {
	duration = 0.55,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.18,
			ease = "out",
			pose = {
				Root = { x = 10 },
				Waist = { y = 45 },
				RightShoulder = { x = 175, z = 25 },
				RightElbow = { x = 85 },
				LeftShoulder = { x = 85, z = -10 },
				LeftHip = { x = 35 },
				RightHip = { x = -15 },
			},
		},
		{
			t = 0.28,
			ease = "in",
			pose = {
				Root = { x = -18 },
				Waist = { y = -30, x = -10 },
				RightShoulder = { x = 100 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = -25, z = -20 },
				LeftHip = { x = 15 },
				RightHip = { x = 10 },
			},
		},
		{ t = 0.55, ease = "inout", pose = guard },
	},
}

-- Thunderclap: a stomp, then the sword thrust skyward.
Library.EchoThunderclap = {
	duration = 0.65,
	keys = {
		{ t = 0, pose = guard },
		{ t = 0.14, ease = "out", pose = { Root = { py = 0.3 }, LeftHip = { x = 85 }, LeftKnee = { x = -85 } } },
		{
			t = 0.24,
			ease = "in",
			pose = {
				Root = { py = -1 },
				LeftHip = { x = 30 },
				LeftKnee = { x = -50 },
				RightHip = { x = 30 },
				RightKnee = { x = -50 },
				RightShoulder = { x = 40, z = 40 },
			},
		},
		{
			t = 0.4,
			ease = "out",
			pose = {
				Root = { py = 0.2, x = 8 },
				RightShoulder = { x = 185 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = 30, z = -60 },
				Neck = { x = -20 },
			},
		},
		{ t = 0.65, ease = "inout", pose = guard },
	},
}

-- Arc Chain: a forked backhand slash.
Library.EchoArcChain = slash(0.45, 0.1, 0.2, {
	Waist = { y = -45 },
	RightShoulder = { x = 155, z = -50 },
	RightElbow = { x = 50 },
	LeftShoulder = { x = 40, z = -30 },
}, {
	Root = { py = -0.5 },
	Waist = { y = 40 },
	RightShoulder = { x = 40, z = 85 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = 70, z = -70 },
	RightHip = { x = 25 },
})

-- Raiju Rush: a low wolf-like sprint that ends in a rising cut.
Library.EchoRaijuRush = {
	duration = 0.65,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.06,
			ease = "out",
			pose = {
				Root = { x = -38, py = -0.9 },
				Waist = { x = -10 },
				RightShoulder = { x = -55, z = 30 },
				LeftShoulder = { x = -45, z = -20 },
				LeftHip = { x = 65 },
				LeftKnee = { x = -50 },
				RightHip = { x = -40 },
				RightKnee = { x = -30 },
			},
		},
		{
			t = 0.42,
			pose = {
				Root = { x = -38, py = -0.9 },
				RightShoulder = { x = -55, z = 30 },
				LeftShoulder = { x = -45, z = -20 },
				LeftHip = { x = 40 },
				RightHip = { x = -10 },
			},
		},
		{
			t = 0.52,
			ease = "out",
			pose = {
				Root = { x = 8, py = 0.4 },
				RightShoulder = { x = 180, z = 10 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = -30, z = -50 },
			},
		},
		{ t = 0.65, ease = "inout", pose = guard },
	},
}

-- Storm Pillar: kneels and plants the sword.
Library.EchoStormPillar = {
	duration = 0.75,
	keys = {
		{ t = 0, pose = guard },
		{
			t = 0.18,
			ease = "out",
			pose = { Root = { py = 0.2 }, RightShoulder = { x = 175 }, RightElbow = { x = 10 } },
		},
		{
			t = 0.32,
			ease = "in",
			pose = {
				Root = { x = -15, py = -1.5 },
				Waist = { x = -15 },
				RightShoulder = { x = 45 },
				RightElbow = { x = 0 },
				LeftShoulder = { x = -10, z = -60 },
				LeftHip = { x = 90 },
				LeftKnee = { x = -90 },
				RightHip = { x = 0 },
				RightKnee = { x = -100 },
			},
		},
		{
			t = 0.62,
			pose = {
				Root = { x = -15, py = -1.5 },
				RightShoulder = { x = 45 },
				LeftShoulder = { x = -10, z = -60 },
				LeftHip = { x = 90 },
				LeftKnee = { x = -90 },
				RightKnee = { x = -100 },
			},
		},
		{ t = 0.75, ease = "inout", pose = guard },
	},
}

-- Raijin's Wrath: rises with arms spread as the storm rolls in.
Library.EchoRaijinsWrath = held(1.35, 1.15, {
	Root = { x = 12 },
	LeftShoulder = { x = 30, z = -125 },
	RightShoulder = { x = 30, z = 125 },
	LeftElbow = { x = 0 },
	RightElbow = { x = 0 },
	Neck = { x = -30 },
	LeftKnee = { x = -25 },
	RightKnee = { x = -15 },
}, 0.3)

-- Rift Blink: a quick hop through the glitch.
Library.EchoRiftBlink = held(0.28, 0.12, {
	Root = { py = 0.3, x = -10 },
	LeftShoulder = { x = 20, z = -40 },
	RightShoulder = { x = 40, z = 30 },
	LeftKnee = { x = -40 },
	RightKnee = { x = -40 },
	LeftHip = { x = 30 },
	RightHip = { x = 30 },
}, 0.06)

-- Second Wind: kneels and breathes.
Library.EchoSecondWind = held(1, 0.8, {
	Root = { py = -1.6, x = -8 },
	Waist = { x = -10 },
	RightHip = { x = 90 },
	RightKnee = { x = -90 },
	LeftHip = { x = 0 },
	LeftKnee = { x = -100 },
	Neck = { x = 25 },
	RightShoulder = { x = 30, z = 10 },
	LeftShoulder = { x = 40, z = -10 },
	LeftElbow = { x = 60 },
}, 0.2)

-- Battle Cry: the sword raised with a roar.
Library.EchoBattleCry = held(0.75, 0.6, {
	Root = { x = 15 },
	Waist = { x = 12 },
	RightShoulder = { x = 175, z = 15 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = 70, z = -70 },
	LeftElbow = { x = 90 },
	Neck = { x = -30 },
	LeftHip = { x = 25 },
	RightHip = { x = -15 },
}, 0.15)

-- Iron Will: a sharp flex as the statuses shatter.
Library.EchoIronWill = held(0.5, 0.32, {
	Root = { py = -0.4 },
	LeftShoulder = { z = -90 },
	RightShoulder = { z = 90 },
	LeftElbow = { x = 110 },
	RightElbow = { x = 110 },
	Neck = { x = -10 },
	LeftHip = { z = -12 },
	RightHip = { z = 12 },
}, 0.08)

-- Rift Burst: curl in, then explode outward.
Library.RiftBurst = {
	duration = 0.45,
	keys = {
		{
			t = 0,
			ease = "out",
			pose = {
				Root = { py = -0.7 },
				Waist = { x = 25 },
				LeftShoulder = { x = 70 },
				RightShoulder = { x = 70 },
				LeftElbow = { x = 110 },
				RightElbow = { x = 110 },
				LeftKnee = { x = -40 },
				RightKnee = { x = -40 },
			},
		},
		{
			t = 0.2,
			ease = "out",
			pose = {
				Root = { py = 0.3, x = 12 },
				Waist = { x = -10 },
				LeftShoulder = { x = 30, z = -135 },
				RightShoulder = { x = 30, z = 135 },
				Neck = { x = -25 },
			},
		},
		{ t = 0.45, ease = "inout", pose = guard },
	},
}

--------------------------------------------------------------------------------
-- Ice, Wind, Shadow, Earth and Rift Echoes.
local function keys(duration, list)
	return { duration = duration, keys = list }
end

-- Ice
Library.EchoFrostLance = keys(0.5, {
	{ t = 0, pose = guard },
	{
		t = 0.12,
		ease = "out",
		pose = {
			Root = { y = -180, py = -0.3 },
			RightShoulder = { x = 170, z = 20 },
			RightElbow = { x = 80 },
			LeftShoulder = { x = 60, z = -30 },
		},
	},
	{
		t = 0.24,
		ease = "in",
		pose = {
			Root = { y = -360, x = -12 },
			Waist = { y = -30 },
			RightShoulder = { x = 95 },
			RightElbow = { x = 0 },
			LeftShoulder = { x = -20, z = -40 },
			LeftHip = { x = 30 },
		},
	},
	{ t = 0.5, ease = "inout", pose = { Root = { y = -360 } } },
})
Library.EchoGlacialGuard = held(1.05, 0.9, {
	Root = { py = -0.6 },
	RightShoulder = { x = 100, z = -60 },
	RightElbow = { x = 70 },
	LeftShoulder = { x = 90, z = -40 },
	LeftElbow = { x = 80 },
	LeftHip = { x = 35 },
	LeftKnee = { x = -40 },
	RightKnee = { x = -30 },
}, 0.06)
Library.EchoGlacierWall = slash(0.6, 0.15, 0.27, {
	Root = { x = 8, py = 0.2 },
	RightShoulder = { x = 190 },
	RightElbow = { x = 10 },
	LeftShoulder = { x = 170 },
}, {
	Root = { x = -30, py = -1.3 },
	Waist = { x = -30 },
	RightShoulder = { x = 50 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = 50 },
	LeftHip = { x = 70 },
	LeftKnee = { x = -80 },
	RightKnee = { x = -60 },
})
Library.EchoFrozenPath = held(0.5, 0.4, {
	Root = { x = -20, py = -0.6 },
	LeftHip = { x = 60 },
	LeftKnee = { x = -50 },
	RightHip = { x = -30 },
	RightShoulder = { x = -40, z = 40 },
	LeftShoulder = { x = 40, z = -60 },
}, 0.12)
Library.EchoAvalancheCrash = keys(0.85, {
	{ t = 0, pose = guard },
	{
		t = 0.15,
		ease = "out",
		pose = {
			Root = { x = 15 },
			RightShoulder = { x = 185 },
			LeftShoulder = { x = 175 },
			LeftHip = { x = 90 },
			LeftKnee = { x = -110 },
			RightHip = { x = 70 },
			RightKnee = { x = -100 },
		},
	},
	{
		t = 0.38,
		pose = {
			Root = { x = -10 },
			RightShoulder = { x = 190 },
			LeftShoulder = { x = 180 },
			LeftHip = { x = 60 },
			LeftKnee = { x = -80 },
		},
	},
	{
		t = 0.47,
		ease = "in",
		pose = {
			Root = { x = -35, py = -1.4 },
			Waist = { x = -25 },
			RightShoulder = { x = 55 },
			LeftShoulder = { x = 55 },
			LeftHip = { x = 80 },
			LeftKnee = { x = -90 },
			RightHip = { x = 10 },
			RightKnee = { x = -100 },
		},
	},
	{
		t = 0.7,
		pose = {
			Root = { x = -33, py = -1.4 },
			RightShoulder = { x = 55 },
			LeftShoulder = { x = 55 },
			LeftHip = { x = 80 },
			LeftKnee = { x = -90 },
			RightKnee = { x = -100 },
		},
	},
	{ t = 0.85, ease = "inout", pose = guard },
})
Library.EchoWintersCoffin = held(0.65, 0.5, {
	Root = { x = -10 },
	Waist = { x = -10 },
	RightShoulder = { x = 90 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = 90 },
	LeftElbow = { x = 0 },
	LeftHip = { x = 40 },
	RightHip = { x = -20 },
}, 0.3)
Library.EchoAbsoluteZero = keys(1.2, {
	{ t = 0, pose = guard },
	{
		t = 0.2,
		ease = "out",
		pose = {
			Root = { py = 0.3, x = 8 },
			RightShoulder = { x = 185 },
			LeftShoulder = { x = 175 },
			Neck = { x = -20 },
		},
	},
	{
		t = 0.4,
		ease = "in",
		pose = {
			Root = { x = -30, py = -1.5 },
			Waist = { x = -30 },
			RightShoulder = { x = 60 },
			LeftShoulder = { x = 60 },
			LeftHip = { x = 75 },
			LeftKnee = { x = -85 },
			RightKnee = { x = -75 },
		},
	},
	{
		t = 1.0,
		pose = {
			Root = { x = -28, py = -1.4 },
			RightShoulder = { x = 62 },
			LeftShoulder = { x = 62 },
			LeftHip = { x = 75 },
			LeftKnee = { x = -85 },
			RightKnee = { x = -75 },
		},
	},
	{ t = 1.2, ease = "inout", pose = guard },
})

-- Wind
Library.EchoGaleRoll = Library.RollForward
Library.EchoWindScythe = keys(0.45, {
	{ t = 0, pose = guard },
	{
		t = 0.08,
		ease = "out",
		pose = { RightShoulder = { x = 160, z = -40 }, LeftShoulder = { x = 160, z = 40 }, Root = { py = 0.1 } },
	},
	{
		t = 0.18,
		ease = "in",
		pose = {
			Root = { py = -0.5 },
			RightShoulder = { x = 60, z = 75 },
			LeftShoulder = { x = 60, z = -75 },
			LeftHip = { x = 30 },
		},
	},
	{ t = 0.45, ease = "inout", pose = guard },
})
Library.EchoUpdraft = keys(0.5, {
	{
		t = 0,
		pose = {
			Root = { py = -1 },
			LeftKnee = { x = -60 },
			RightKnee = { x = -60 },
			LeftHip = { x = 40 },
			RightHip = { x = 40 },
		},
	},
	{
		t = 0.35,
		ease = "out",
		pose = {
			Root = { y = -360, py = 1.4 },
			RightShoulder = { x = 175 },
			LeftShoulder = { x = 160, z = -20 },
			LeftKnee = { x = -30 },
		},
	},
	{ t = 0.5, ease = "inout", pose = { Root = { y = -360 } } },
})
Library.EchoTempestStep = held(0.5, 0.35, {
	Root = { py = 0.3 },
	LeftKnee = { x = -60 },
	LeftHip = { x = 50 },
	LeftShoulder = { x = 20, z = -70 },
	RightShoulder = { x = 20, z = 70 },
}, 0.1)
Library.EchoCycloneCutter = keys(0.55, {
	{ t = 0, pose = { Root = { py = -0.6 }, Waist = { y = 60 }, RightShoulder = { x = 90, z = 110 } } },
	{
		t = 0.45,
		ease = "linear",
		pose = {
			Root = { y = -720, py = -0.4 },
			RightShoulder = { x = 88, z = 100 },
			RightElbow = { x = 0 },
			LeftShoulder = { x = 70, z = -90 },
		},
	},
	{ t = 0.55, ease = "out", pose = { Root = { y = -720 } } },
})
Library.EchoVacuumBlade = slash(0.8, 0.3, 0.42, {
	Root = { py = -0.6 },
	Waist = { y = 50 },
	RightShoulder = { x = 90, z = 100 },
	RightElbow = { x = 10 },
	LeftShoulder = { x = 40, z = -20 },
}, {
	Root = { py = -0.7 },
	Waist = { y = -40 },
	RightShoulder = { x = 90, z = -30 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = -10, z = -60 },
	RightHip = { x = 25 },
})
Library.EchoHeavenSplitter = keys(1.0, {
	{ t = 0, pose = guard },
	{
		t = 0.4,
		ease = "out",
		pose = {
			Root = { x = 10, py = 0.3 },
			RightShoulder = { x = 185 },
			LeftShoulder = { x = 175 },
			Neck = { x = -20 },
		},
	},
	{
		t = 0.6,
		ease = "in",
		pose = {
			Root = { x = -30, py = -1 },
			Waist = { x = -25 },
			RightShoulder = { x = 50 },
			LeftShoulder = { x = 50 },
			LeftHip = { x = 65 },
			LeftKnee = { x = -60 },
			RightHip = { x = -40 },
		},
	},
	{
		t = 0.85,
		pose = {
			Root = { x = -28, py = -1 },
			RightShoulder = { x = 50 },
			LeftShoulder = { x = 50 },
			LeftHip = { x = 65 },
			LeftKnee = { x = -60 },
		},
	},
	{ t = 1.0, ease = "inout", pose = guard },
})

-- Shadow
Library.EchoShadeStep = held(0.5, 0.3, {
	Root = { py = -2.2, x = -20 },
	LeftHip = { x = 100 },
	LeftKnee = { x = -120 },
	RightHip = { x = 100 },
	RightKnee = { x = -120 },
	LeftShoulder = { x = 30 },
	RightShoulder = { x = 30 },
}, 0.15)
Library.EchoUmbralFangs = held(0.5, 0.35, {
	Root = { py = -0.3 },
	Waist = { y = 20 },
	RightShoulder = { x = 60, z = -30 },
	RightElbow = { x = 90 },
	LeftShoulder = { x = 40, z = -60 },
	LeftElbow = { x = 60 },
}, 0.12)
Library.EchoShadeClone = held(0.45, 0.3, {
	Root = { z = 20, py = -0.3 },
	Waist = { z = 10 },
	LeftShoulder = { z = -60 },
	RightShoulder = { z = 60 },
}, 0.12)
Library.EchoVoidGrasp = held(0.6, 0.45, {
	Root = { x = -25, py = -1.3 },
	Waist = { x = -25 },
	LeftShoulder = { x = 60 },
	LeftElbow = { x = 0 },
	RightShoulder = { x = -20, z = 40 },
	LeftHip = { x = 70 },
	LeftKnee = { x = -80 },
	RightKnee = { x = -70 },
}, 0.22)
Library.EchoNightfallVeil = held(0.8, 0.65, {
	Root = { x = 8 },
	RightShoulder = { x = 180, z = -10 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = 60, z = -90 },
	Neck = { x = -20 },
}, 0.25)
Library.EchoEclipseRend = held(0.35, 0.25, {
	Root = { py = -0.8, x = -15 },
	Waist = { y = 40 },
	RightShoulder = { x = -30, z = 30 },
	LeftHip = { x = 50 },
	LeftKnee = { x = -60 },
}, 0.08)
Library.EchoEclipse = held(1.0, 0.8, {
	Root = { x = 12, py = 0.2 },
	LeftShoulder = { x = 30, z = -120 },
	RightShoulder = { x = 170, z = 10 },
	RightElbow = { x = 0 },
	Neck = { x = -30 },
}, 0.3)

-- Earth
Library.EchoStonePillar = held(0.55, 0.4, {
	Root = { x = -20, py = -1.2 },
	Waist = { x = -25 },
	RightShoulder = { x = 40 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = -20, z = -50 },
	LeftHip = { x = 60 },
	LeftKnee = { x = -70 },
}, 0.15)
Library.EchoRockToss = keys(0.65, {
	{ t = 0, pose = guard },
	{ t = 0.1, ease = "out", pose = { Root = { py = 0.2 }, LeftHip = { x = 80 }, LeftKnee = { x = -80 } } },
	{
		t = 0.18,
		ease = "in",
		pose = { Root = { py = -0.6 }, LeftHip = { x = 20 }, LeftKnee = { x = -30 }, RightShoulder = { x = 30 } },
	},
	{
		t = 0.3,
		ease = "out",
		pose = {
			Root = { x = 15 },
			RightShoulder = { x = 200 },
			LeftShoulder = { x = 200 },
			RightElbow = { x = 40 },
			LeftElbow = { x = 40 },
		},
	},
	{
		t = 0.4,
		ease = "in",
		pose = {
			Root = { x = -20 },
			Waist = { x = -20 },
			RightShoulder = { x = 80 },
			LeftShoulder = { x = 80 },
			RightElbow = { x = 0 },
			LeftElbow = { x = 0 },
			LeftHip = { x = 35 },
		},
	},
	{ t = 0.65, ease = "inout", pose = guard },
})
Library.EchoQuakeStomp = keys(0.6, {
	{ t = 0, pose = guard },
	{
		t = 0.15,
		ease = "out",
		pose = {
			Root = { py = 0.4 },
			LeftHip = { x = 100 },
			LeftKnee = { x = -90 },
			LeftShoulder = { z = -70 },
			RightShoulder = { x = 30, z = 70 },
		},
	},
	{
		t = 0.25,
		ease = "in",
		pose = {
			Root = { py = -1.3 },
			LeftHip = { x = 40 },
			LeftKnee = { x = -60 },
			RightHip = { x = 40 },
			RightKnee = { x = -60 },
			LeftShoulder = { z = -50 },
			RightShoulder = { z = 50 },
		},
	},
	{
		t = 0.45,
		pose = {
			Root = { py = -1.2 },
			LeftHip = { x = 40 },
			LeftKnee = { x = -60 },
			RightHip = { x = 40 },
			RightKnee = { x = -60 },
		},
	},
	{ t = 0.6, ease = "inout", pose = guard },
})
Library.EchoGraniteSkin = held(0.5, 0.35, {
	Root = { py = -0.8 },
	Waist = { x = 15 },
	LeftShoulder = { x = 30, z = -60 },
	RightShoulder = { x = 30, z = 60 },
	LeftElbow = { x = 100 },
	RightElbow = { x = 100 },
	LeftHip = { x = 30 },
	RightHip = { x = 30 },
	LeftKnee = { x = -40 },
	RightKnee = { x = -40 },
}, 0.15)
Library.EchoTectonicRift = held(0.65, 0.5, {
	Root = { x = -30, py = -0.8 },
	RightShoulder = { x = -40, z = 30 },
	RightElbow = { x = 0 },
	LeftShoulder = { x = 60 },
	LeftHip = { x = 60 },
	RightHip = { x = -40 },
	LeftKnee = { x = -40 },
}, 0.1)
Library.EchoEarthenPrison = keys(0.65, {
	{ t = 0, pose = guard },
	{
		t = 0.15,
		ease = "out",
		pose = { LeftShoulder = { x = 70, z = -100 }, RightShoulder = { x = 70, z = 100 }, Root = { py = -0.3 } },
	},
	{
		t = 0.3,
		ease = "in",
		pose = {
			LeftShoulder = { x = 90 },
			RightShoulder = { x = 90 },
			LeftElbow = { x = 0 },
			RightElbow = { x = 0 },
			Root = { py = -0.5, x = -10 },
		},
	},
	{ t = 0.5, pose = { LeftShoulder = { x = 90 }, RightShoulder = { x = 90 }, Root = { py = -0.5, x = -10 } } },
	{ t = 0.65, ease = "inout", pose = guard },
})
Library.EchoMountainsWrath = held(1.1, 0.95, {
	Root = { x = 8 },
	LeftShoulder = { x = 180, z = -10 },
	LeftElbow = { x = 0 },
	RightShoulder = { x = 30, z = 40 },
	Neck = { x = -25 },
	LeftHip = { x = 20 },
}, 0.3)

-- Rift
Library.EchoGrappleHook = keys(0.45, {
	{ t = 0, pose = guard },
	{
		t = 0.12,
		ease = "out",
		pose = { Waist = { y = 25 }, LeftShoulder = { x = 150, z = -40 }, LeftElbow = { x = 60 } },
	},
	{
		t = 0.2,
		ease = "in",
		pose = { Waist = { y = -25 }, LeftShoulder = { x = 95 }, LeftElbow = { x = 0 }, Root = { x = -10 } },
	},
	{ t = 0.45, ease = "inout", pose = guard },
})
Library.EchoAfterimage = held(0.35, 0.25, {
	Root = { py = -0.3 },
	LeftShoulder = { z = -40 },
	RightShoulder = { x = 60, z = 20 },
	Neck = { x = -10 },
}, 0.08)
Library.EchoRiftBarrier = held(0.5, 0.35, {
	Root = { py = -0.4 },
	LeftShoulder = { x = 90, z = -30 },
	RightShoulder = { x = 90, z = 30 },
	LeftElbow = { x = 90 },
	RightElbow = { x = 90 },
}, 0.1)
Library.EchoMirrorGuard = held(1.2, 1.05, {
	Root = { py = -0.5 },
	RightShoulder = { x = 90, z = -20 },
	RightElbow = { x = 20 },
	LeftShoulder = { x = 80, z = -30 },
	LeftElbow = { x = 60 },
	LeftHip = { x = 30 },
	RightHip = { x = -15 },
}, 0.06)

return Library
