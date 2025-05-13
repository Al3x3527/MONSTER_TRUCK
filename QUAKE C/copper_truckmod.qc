//====================================
//DEFS
//====================================
.float		lifetime_finished;
.float		notrace;		// entity will be invisible to traceline2()
.vector		oldvelocity;	// necessary for getting projectiles to pass through .notrace entities
.entity		trueowner;		// now this is getting dumb
float	trace_debug;
.float		customflags;	// inpain, axehitme, zapped, etc, see constants.qc
#pragma noref 0
//====================================
//CONSTANTS
//====================================
// edict.customflags
const float	CFL_LEFTY = 1;	// used by slidemovers (scrags) to alternate strafe direction
const float	CFL_RETURNED = 1;	// zombie has already respawned in nightmare
const float	CFL_INVLIGHT = 1;	// for backwards bmover light fade behavior
const float	CFL_ZAPPED = 2;
const float	CFL_AXEHITME = 4;
const float	CFL_LOCKED = 16;	// special state-independent deactivation
const float	CFL_INPAIN = 16;	// zombie should knockdown soon
const float	CFL_KNOCKEDDOWN = 32;	// zombie is down
const float	CFL_PLUNGE = 64;	// has fallen in a death pit
const float	CFL_SPAWNER = 128;	// is a generator of monsters
const float	CFL_UNDYING = 256;	// god mode minus one point (player)
const float	CFL_LIQUID_IMMUNE = 512;	// monster spawned touching slime or lava, so assume designer wants it immune to damage
const float	CFL_MELEEONLY = 1024;	// has no ranged attack (monster)
const float	CFL_LIMBO = 2048;	// waiting in teleport limbo (coop, player)
const float	CFL_OMNIVISION = 4096;	// eyes in back of head
// type parameters for damage functions
const float DMGTYPE_EXPLOSION = 1;	// half to shamblers
const float DMGTYPE_ZKILL = 2;	// death to zombies (direct EXPLOSION always kills zombies but splash doesn't)
const float DMGTYPE_NOARMOR = 4;	// bypass armor
const float DMGTYPE_MELEE = 8;	// inflictor == attacker
const float DMGTYPE_TELEFRAG = 16;
const float DMGTYPE_LIGHTNING = 32;
const float DMGTYPE_DROWNING = 64;
const float DMGTYPE_FALLING = 128;	// everyone's favorite
const float DMGTYPE_LAVA = 256;
const float DMGTYPE_SLIME = 512;
const float DMGTYPE_CRUSH = 1024;
const float DMGTYPE_SCRIPT = 2048;	// target_items, invoke, etc

const float	TRACE_NOMONSTERS = 1;
const float	TRACE_WATER = 2;

// ===================
//	MATHS. --from Copper
// ===================

// frikqcc doesn't like it when i swizzle directly
// TODO: see if fteqcc cares
vector(float x, float y, float z) Vector =
{
	local vector swiz;
	swiz_x = x;
	swiz_y = y;
	swiz_z = z;
	return swiz;
}

vector(float num) SinCos =
{
	local vector angle, vf, vu, vr, result;

	vf = v_forward;
	vu = v_up;
	vr = v_right;

	angle = '0 1 0' * num;
	makevectors(angle);
	result = Vector(v_forward_y, v_forward_x, 0);

	v_forward = vf;
	v_up = vu;
	v_right = vr;

	return result;
}

float(float num) sin =
{
	vector temp;
	temp = SinCos(num);
	return temp_x;
}

float(float num) cos =
{
	vector temp;
	temp = SinCos(num);
	return temp_y;
}

vector(vector a, vector b) CrossProduct =
{
	vector c;

	c_x = a_y * b_z - a_z * b_y;
	c_y = a_z * b_x - a_x * b_z;
	c_z = a_x * b_y - a_y * b_x;

	return c;
}

float(float a, float b) min = { if (a <= b) return a; return b; }
float(float a, float b) max = { if (a >= b) return a; return b; }

//====================================
//UTILITY
//====================================
float(entity who) has_invis = { return (who.items & IT_INVISIBILITY || who.invisible_finished > time); }

/*
===============
dprint_float stuff

bc i'm tired of ftos cutting off all the important digits
===============
*/
void dprint_digit(float f) =
{
	float d;
	d = floor(f);
	d = mod(d, 10);

	if (d == 0)		dprint("0");
	else if (d == 1)	dprint("1");
	else if (d == 2)	dprint("2");
	else if (d == 3)	dprint("3");
	else if (d == 4)	dprint("4");
	else if (d == 5)	dprint("5");
	else if (d == 6)	dprint("6");
	else if (d == 7)	dprint("7");
	else if (d == 8)	dprint("8");
	else if (d == 9)	dprint("9");
}

void dprint_int(float f, float numdigits) =
{
	float tmp;

	if (f == 0)
	{
		dprint("0");
		return;
	}

	if (f < 0)
	{
		dprint("-");
		f = fabs(f);
	}

	if (numdigits <= 0)
	{
		tmp = f;
		numdigits = 1;
		while (tmp >= 1) {
			tmp = tmp / 10;
			numdigits = numdigits * 10;
		}
	}

	while (numdigits > 1)
	{
		numdigits = numdigits / 10;
		tmp = f / numdigits;
		dprint_digit(tmp);
	}
}

void dprint_float(float f) =
{
	float intpart, decpart, isNegative;

	isNegative = FALSE;

	if (f == 0)
	{
		dprint("0");
		return;
	}

	if (f < 0)
	{
		// easier this way
		isNegative = TRUE;
		f = fabs(f);
	}

	// 1: stuff the integer part.
	intpart = floor(f);
	if (isNegative)
		dprint("-");
	dprint_int(intpart, 0);

	// 2: stuff the decimal point.
	dprint(".");

	// 3: stuff the decimal part.
	decpart = mod(f, 1);
	decpart = decpart * 10000;
	dprint_int(decpart, 10000);
}

void dprint_vector(vector v) =
{
	dprint("( ");
	dprint_float(v_x);
	dprint(" ");
	dprint_float(v_y);
	dprint(" ");
	dprint_float(v_z);
	dprint(" )");
}
/*
================================================================

	PROJECTILES

================================================================
*/


/*
============
traceline2

a more robust wrapper for traceline() that can ignore a wider array of entities.
performs one or more staggered traceline()s until the trace_ent isn't something we
actually want to ignore, so what would be one trace can turn into several.
============
*/
void(vector start, vector end, entity ignore, float traceflags) traceline2 =
{
	entity ig = ignore;
//entity lastent = world;
vector src = start;
vector lastend = start;
float traces = 0;
float nomonsters = 0;

if (traceflags & TRACE_NOMONSTERS) nomonsters = TRUE;

float	t_allsolid = 2;
float	t_startsolid = -1;
float	t_inopen = -1;
float	t_inwater = -1;

if (trace_debug)
{
	dprint("tracing from ");
	dprint_vector(src);
	dprint(" to ");
	dprint_vector(end);
	dprint("\n");
}

// check for trace-through cases and repeat
do {
	if (trace_debug)
	{
		dprint("  trace ");
		dprint_vector(src);
		dprint(" to ");
		dprint_vector(end);
		dprint("\n");
	}
	traceline(src, end, nomonsters, ig);

	// preserve the accuracy of the trace result flags
	if (t_startsolid == -1) t_startsolid = trace_startsolid;
	if (!trace_startsolid)
	{
		t_allsolid = min(t_allsolid, trace_allsolid);
		t_inopen = max(t_inopen, trace_inopen);
		t_inwater = max(t_inwater, trace_inwater);

		if (trace_ent.deadflag == DEAD_DYING || 	// don't let guys in death frames who aren't nonsolid yet act like solid walls to bullets
			trace_ent == ignore || 					// always ignore the original ignore ent on future loops
			trace_ent.movetype == MOVETYPE_NOCLIP || // don't shoot noclipping players
			invis_miss_check(trace_ent, start, end - start) ||
			trace_ent.notrace)						// flag to make things game-functionally nonsolid (monsterclip/etc)
		{
			// if two entities that are both to be ignored are touching, the trace will
			// fail with a distance of zero once 'ig' changes, so nudge forward one unit
			// to make sure the point of origin isn't touching the old ig
			lastend = trace_endpos;
			src = trace_endpos + normalize(end - start);
			ig = trace_ent;
			if (trace_debug) dprint3("    hit ", trace_ent.classname, ", trying again\n");
		} else ig = world;
	} else
	{
		// if the nudge forward put the trace start in a solid, the last trace should 
		// have been the end. this can happen when a notrace surface and a legit solid 
		// surface are coincident in the path of the trace2, and the notrace one is the 
		// one quake 'sees' first.
		if (trace_debug) dprint("  trace started solid!\n");
		trace_endpos = lastend;
		ig = world;
	}
	traces++;
} while (ig != world);	// true if we hit a wall or hit nothing

if (trace_debug) dprint3("trace complete after ", ftos(traces), " traces \n");

// unify global trace results so the calling function can pretend it only made one trace
float lastfrac = vlen(start - trace_endpos) / vlen(start - end);
entity lastent = trace_ent;
if (traceflags & (TRACE_NOMONSTERS | TRACE_WATER) == TRACE_WATER)
{
	// thanks to a structural oddity in SV_ClipToLinks (world.c), a traceline() without nomonsters
	// doesn't properly populate the open/inwater trace flags, so we have to do another nomonsters
	// traceline2 over the path of the last one to catch the case of crossing water contents.

	// we can't just check pointcontents at start and end because it doesn't catch when mappers do
	// wacky things with water volumes (ie the E4 entry in the original start.bsp), and it can't be
	// a singular traceline() because a monster might be looking through a notrace bmodel into water.
	//dprint(" tracing again with nomonsters to get trace flags right\n");
	traceline2(start, trace_endpos, ignore, TRACE_NOMONSTERS);
} else
{
	trace_startsolid = t_startsolid;
	trace_allsolid = t_allsolid;
	trace_inopen = t_inopen;
	trace_inwater = t_inwater;
}
trace_fraction = lastfrac;
trace_ent = lastent;

if (trace_debug) {
	if (trace_ent)
		dprint3("  entity: ", trace_ent.classname, "\n");
	dprint3("  end: ", vtos(trace_endpos), "\n");
	dprint3("  fraction: ", ftos(trace_fraction * 100), "%\n");
	dprint3("  startsolid: ", ftos(trace_startsolid), "\n");
	dprint3("  allsolid: ", ftos(trace_allsolid), "\n");
	dprint3("  inopen: ", ftos(trace_inopen), "\n");
	dprint("----------\n");
	//	dprint3("  inwater: ", ftos(trace_inwater), "\n----------\n");
	}
}
/*
============
projectile_passthru_think

think function to make a projectile ignore what it just hit
the new owner has been set by this point
============
*/
void() projectile_passthru_think =
{
	self.flags = not(self.flags, FL_ONGROUND);
	self.velocity = self.oldvelocity;
	self.think = self.think1;
	self.nextthink = self.pain_finished;

	// nudge the projectile forward a tiny bit to be inside its new owner
	setorigin(self, self.origin + normalize(self.velocity) * 0.1);
	// if the old owner and the new owner are touching at the point that the
	// projectile crosses over, next frame it'll be coincident with both old
	// and new, the trace in sv_move will wind up being allsolid, and the
	// projectile will travel through worldspawn.
}
/*
============
projectile_toss_think

when a passthru overrides server physics for a TOSS projectile, we must
restore a recent enough velocity that the projectile appeared not to touch.
grenades change velocity every frame, so they have to save it near-continuously
============
*/
void() projectile_toss_think =
{
	if (time > self.lifetime_finished)
	{
		self.th_die();
		return;
	}
	if (self.velocity == VEC_ORIGIN)	// stopped on the ground
	{
		self.think = self.th_die;
		self.nextthink = self.lifetime_finished;
		//	bprint3("at rest, exploding in ", ftos(self.nextthink), " seconds\n");
			self.th_die = SUB_Null;
			self.lifetime_finished = 0;
			self.solid = SOLID_NOT;
			return;
		}

		self.flags = not(self.flags, FL_ONGROUND);
		self.oldvelocity = self.velocity;
		self.nextthink = time + 0.05;	// 10hz is probably enough, but 20hz is surely twice as good
}
/*
============
projectile_valid_passthru

returns TRUE in cases where we pass through and should not collide
============
*/
float() projectile_valid_passthru =
{
	// SOLID_NOT entities touch SOLID_BSP by default without generating touch events.
	// gibs had to be made SOLID_BBOX in order to make selectively passing through 
	// notrace/monsterclip even possible, so they need special handling by our owner-
	// changing hackery to ensure they stay nonsolid in the other cases too
	if (self.type == "gib")
	{
		if (other.movetype == MOVETYPE_PUSH || other.solid == SOLID_BSP)
			return other.notrace;
		return TRUE;
	}

	if (other.deadflag == DEAD_DYING || // corpses not yet on the ground
		other.notrace || 				// specially marked (monsterclip)
		invis_miss_check(other,self.origin,self.velocity) ||
		other.movetype == MOVETYPE_NOCLIP || // ignore noclipping players
		other == self.trueowner)		// still track the original owner - there are cases when monsters 
										// or players firing fat FLYMISSILE projectiles into an adjacent 
										// monsterclip can be hit by them when the owner switches
		return TRUE;

	return FALSE;
}
/*
============
projectile_passthru

we can't alter physics stuff to make the projectile physically penetrate during
touch/physics, so set an immediate think to 'repair' the state of the projectile
============
*/
void() projectile_passthru =
{
	self.owner = other;

// our nextthink was probably to explode or remove, so save that
self.think1 = self.think;
self.pain_finished = self.nextthink;

self.think = projectile_passthru_think;
self.nextthink = time;
}
/*
============
CheckProjectilePassthru

called within every projectile touch function, returns TRUE if pierced an otherwise solid entity
============
*/
float() CheckProjectilePassthru =
{
	if (!other) return FALSE;	// always collide with world
	if (other == self.owner) return FALSE;	// this actually shouldn't have been called, but: don't touch owner

	if (other.classname == "func_void")
	{
		// go away at the bottoms of pits
		SUB_RemoveSoon();
		return TRUE;
	}

	// handle overriding the quake physics with our own desired result
	if (projectile_valid_passthru())
	{
		projectile_passthru();
		return TRUE;
	}

	return FALSE;
}
void() projectile_touch_null = { CheckProjectilePassthru(); }
/*
========
invis_miss_check

when invisible, to split the difference between the near-invulnerability of notrace
and the cheap weak feeling of catching a stray grenade because you dodged wrong,
projectiles and hitscan are verified against a thin cylinder (20u diameter) so most
incidental or glancing hits miraculously miss, while only the real dead-on shots land
========
*/
float(entity tgt, vector start, vector dir) invis_miss_check =
{
	if (!has_invis(tgt))
		return FALSE;
	vector p = CrossProduct('0 0 1', normalize(dir));
	float d = (start - tgt.origin) * p;
	return (fabs(d) >= 10);
}
/*
===========
alive --Copper

Verify if entity can still be attacked
Returns FALSE if e should be permanently forgotten
============
*/
float(entity e) alive =
{
	if (e.health <= 0) return FALSE;
// also consider a downed zombie to be dead, instead of waving a chainsaw over its body forever
if (e.customflags & (CFL_KNOCKEDDOWN)) return FALSE;
// coop spectating is a deadflag without being out of health
if (e.deadflag) return FALSE;
return TRUE;
}

/*
==============================================================================

MEAT FIREWORKS

moved from player.qc

the rule: gibs pass through .notrace monsterclip but heads do not, because heads
are kind of the trophies for gibbing something and should hang around rather
than fall through grates (also they look too big)

==============================================================================
*/

vector(float dm) GibVelocityForHealth =
{
	vector v;
	float voom;

	v_x = 150 * crandom();
	v_y = 150 * crandom();
	v_z = 150 + 150 * random();

	voom = max(1, min(10, dm * dm / 5000));

	return v * voom;
}

/*
========
kaboom

for making explosions when and where you please
========
*/
entity(vector org, float damg, entity parent, float multi) kaboom =
{
	local entity boom;

	boom = spawn();
	setorigin(boom, org);
	boom.nextthink = time;
	boom.think = BecomeExplosion;

	//if (damg > 0) T_RadiusDamage(boom, parent, damg, boom, DMGTYPE_EXPLOSION);
	if (damg > 0) T_RadiusDamage(boom, parent, damg, boom);

	return boom;
}

/*
================================================================

	MISC SUBSTITUTION FUNCTIONS

================================================================
*/

/*
=============
SUB_Remove/SUB_RemoveSoon

RemoveSoon is to be used during touch functions to avoid touchlinks errors
===============
*/
//void() SUB_Remove = { remove(self); }
void() SUB_RemoveSoon =
{
	// ensure no shenanigans take place in the next hundredth of a second
	// otherwise we get weirdness like items being picked up twice at high framerates
	self.model = string_null;
	self.solid = SOLID_NOT;
	self.touch = SUB_Null;
	self.use = SUB_Null;

	self.think = SUB_Remove;
	self.nextthink = time;
}
