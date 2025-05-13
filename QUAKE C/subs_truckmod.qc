//====================================
//DEFS
//====================================

float FL_VEHICLE = 16384;
float FL_CAMERA = 32768;
float I_AM_TURRET = 262144; //dumptruck_ds
.entity driver;
.entity passenger;
.entity turret;
.entity collider2;
.entity collider1;
.entity brushcollider;
.entity weapon1, weapon2;

.entity wheel1, wheel2, wheel3, wheel4;

.vector flyhack; //could we use oldvelocity?
.float fakeowner;

/*
============
W_ChangeWeapon

============
*/
void() SUB_W_ChangeWeapon =
{
	local	float	it, am, fl;

	it = self.items;
	am = 0;

	if (!self.impulse) return;

	//truck mod just this check
	if (self.flags & FL_VEHICLE) {
		if (self.impulse <= 4){
			truck_ImpulseCommands(); //shouldn't need
			return; //truck impulses in m_truckmod.qc
			}
	}

	if (self.impulse == 1)
	{
		fl = IT_AXE;
	} else if (self.impulse == 2)
	{
		fl = IT_SHOTGUN;
		if (self.ammo_shells < 1)
			am = 1;
	} else if (self.impulse == 3)
	{
		fl = IT_SUPER_SHOTGUN;
		if (self.ammo_shells < 2)
			am = 1;
	} else if (self.impulse == 4)
	{
		fl = IT_NAILGUN;
		if (self.ammo_nails < 1)
			am = 1;
	} else if (self.impulse == 5)
	{
		fl = IT_SUPER_NAILGUN;
		if (self.ammo_nails < 2)
			am = 1;
	} else if (self.impulse == 6)
	{
		fl = IT_GRENADE_LAUNCHER;
		if (self.ammo_rockets < 1)
			am = 1;
	} else if (self.impulse == 7)
	{
		fl = IT_ROCKET_LAUNCHER;
		if (self.ammo_rockets < 1)
			am = 1;
	} else if (self.impulse == 8)
	{
		fl = IT_LIGHTNING;
		if (self.ammo_cells < 1)
			am = 1;
	} else
	{
		dprint("WARNING: W_ChangeWeapon: bad impulse: ");
		dprint(ftos(self.impulse));
		dprint("\n");
		return;
	}

	self.impulse = 0;

	if (!(self.items & fl))
	{	// don't have the weapon or the ammo
		sprint(self, "no weapon.\n");
		return;
	}

	if (am)
	{	// don't have the ammo
		sprint(self, "not enough ammo.\n");
		return;
	}

	//
	// set weapon, set ammo
	//
		self.weapon = fl;
		W_SetCurrentAmmo();
};

void() SUB_PlayerPreThink =
{
	local float do_ladder_physics;

	if (intermission_running)
	{
		IntermissionThink();	// otherwise a button could be missed between
		return;					// the think tics
	}

	if (self.view_ofs == '0 0 0')
		{
			Cutscene_Think();      // Check for cutscene stuff.
			return;        // intermission or finale
	}

	// note that this code block is here, before the tests which check
	// whether the player is dead, so that the player's gravity will be
	// correctly updated even if they e.g. fell off a ladder because
	// they died -- iw
	if (self.onladder)
	{
		do_ladder_physics = TRUE;
		self.gravity = 0.0000001;	// not zero, because zero means "default"
		self.onladder = 0;
	} else
	{
		do_ladder_physics = FALSE;
		self.gravity = self.wantedgravity;
	}

	// If just spawned in, try to recover previous fog values from own client entity, if any
	if (cleanUpClientStuff)
		fog_setFromEnt(self, self);

	makevectors(self.v_angle);		// is this still used

	CheckRules();
	WaterMove();

	if (self.waterlevel == 2)
		CheckWaterJump();

	if (self.deadflag >= DEAD_DEAD)
	{
		PlayerDeathThink();
		return;
	}

	if (self.deadflag == DEAD_DYING)
		return;	// dying, so do nothing

//johnfitz ladder conditions //added from Rubicon2 client.qc -- dumptruck_ds
if (do_ladder_physics)
{
	if (self.button2)
	{
		PlayerClimb();

		/* no ladder footsteps for now
		if (time > self.ladder_step_finished) {
			r = random();
			if (r > 0.66)
				sound (self, CHAN_BODY, "ladder/metal1.wav", 0.5, ATTN_NORM);
			else if (r > 0.33)
				sound (self, CHAN_BODY, "ladder/metal2.wav", 0.5, ATTN_NORM);
			else
				sound (self, CHAN_BODY, "ladder/metal3.wav", 0.5, ATTN_NORM);
			self.ladder_step_finished = time + 0.3;
		}
		*/
	} else
	{
		self.flags = self.flags | FL_JUMPRELEASED;
		self.velocity = 0.9 * self.velocity;
		self.velocity_z = 0;
	}
} else
{
	//truckmod ======================================================
	if !(self.flags & FL_VEHICLE) {
		if (self.button2)
		{
			PlayerJump();
		} else
		{
			self.flags = self.flags | FL_JUMPRELEASED;
		}
	}
} //johnfitz

// teleporters can force a non-moving pause time
	if (time < self.pausetime)
		self.velocity = '0 0 0';

	if (time > self.attack_finished && self.currentammo == 0 && self.weapon != IT_AXE)
	{
		self.weapon = W_BestWeapon();
		W_SetCurrentAmmo();
	}
	// from copper -- dumptruck_ds
	if (self.movetype == MOVETYPE_NOCLIP)
	{
		self.flags = self.flags | FL_FLY;
	}
};

void() SUB_PlayerPostThink =
{

	if (self.view_ofs == '0 0 0')
		return;		// intermission or finale
	if (self.deadflag)
		return;

	// do weapon stuff

		W_WeaponFrame();

		// check to see if player landed and play landing sound
			if ((self.jump_flag < -300) && (self.flags & FL_ONGROUND) && (self.health > 0))
			{
				if (self.watertype == CONTENT_WATER)
					sound(self, CHAN_BODY, "player/h2ojump.wav", 1, ATTN_NORM);
				else if (self.jump_flag < -650)
				{
					self.deathtype = "falling";
					T_Damage(self, world, world, 5);
					self.deathtype = "";
					sound(self, CHAN_VOICE, "player/land2.wav", 1, ATTN_NORM);
				} else
					sound(self, CHAN_VOICE, "player/land.wav", 1, ATTN_NORM);

				self.jump_flag = 0;
			}

			if (!(self.flags & FL_ONGROUND))
				self.jump_flag = self.velocity_z;

			if (self.health > self.max_health) //dumptruck_ds --  this replaces item_megahealth_rot in items.qc

			{
				if (self.megahealth_rottime < time)
					{
							self.megahealth_rottime = time + 1;
							self.health = self.health - 1;
					}

				else if (self.health <= 100)   //thanks ydrol!!!
				self.items = self.items - (self.items & IT_SUPERHEALTH);
		}

		CheckPowerups();
		// from Copper -- dumptruck_ds
		if (self.movetype != MOVETYPE_NOCLIP)
		{
			self.flags = not(self.flags, FL_FLY);
		}
		//truckmod fakeowner =====================================================================
		if (self.fakeowner) { //don't clear all owners
			if (self.fakeowner < time) {
				self.fakeowner = 0;
				self.owner = 0;
			}
		}

};

float() SUB_FindTarget =
{
	local entity	client;
	local float		r;

	// if the first spawnflag bit is set, the monster will only wake up on
	// really seeing the player, not another monster getting angry

	// spawnflags & 3 is a big hack, because zombie crucified used the first
	// spawn flag prior to the ambush flag, and I forgot about it, so the second
	// spawn flag works as well
		if (sight_entity_time >= time - 0.1 && !(self.spawnflags & 3))
		{
			client = sight_entity;
			if (client.enemy == self.enemy)
				return TRUE;
		} else
		{
			client = checkclient();
			if (!client)
				return FALSE;	// current check entity isn't in PVS
		}

		if ((self.spawnflags & PASSIVE_UNTIL_ATTACKED) || (self.spawnflags & PASSIVE_ALWAYS))
			return FALSE;

		if (client.flags & FL_NOTARGET || client.movetype == MOVETYPE_NOCLIP) // from Copper -- dumptruck_ds
			return FALSE;

		if (client.health <= 0)
			return FALSE;

		if (client.classname != "player")
			if (client.enemy.health <= 0)
				return FALSE;

		if (client == self.enemy)
			return FALSE;

		if (client.flags & FL_NOTARGET)
			return FALSE;
		if (client.items & IT_INVISIBILITY)
			return FALSE;

		r = range(client);
		if (r == RANGE_FAR)
			return FALSE;

		if (!visible(client))
			return FALSE;

		if (r == RANGE_NEAR)
		{
			if (client.show_hostile < time && !infront(client))
				return FALSE;
		} else if (r == RANGE_MID)
		{
			if ( /* client.show_hostile < time || */ !infront(client))
				return FALSE;
		}

		//
		// got one
		//
			self.enemy = client;
			if (self.enemy.classname != "player")
			{
				self.enemy = self.enemy.enemy;
				if (self.enemy.classname != "player")
				{
					self.enemy = world;
					return FALSE;
				}
			}
			//truckmod just this check
			if (self.enemy.flags & FL_VEHICLE) {
				local entity truck = self.enemy.owner;
				if (truck.turret) {
					local entity gunner = truck.turret;
					if !(gunner.enemy) {
						gunner.enemy = self;
					//	dprint("findtarget force turret e\n");
					}
				}
				self.enemy = truck.driver; //target the fake player
				if !(alive(self.enemy)) {
				//	dprint("findtarget dead driver\n");
					return FALSE;
				}
				//dprint("FL_VEHICLE FindTarget FoundTarget\n");
			}
			FoundTarget();

			return TRUE;
};
