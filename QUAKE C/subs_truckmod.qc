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

.entity wheel1, wheel2, wheel3, wheel4;

.vector flyhack; //could we use oldvelocity?

// --------------------------------
// ImpulseCommands --Copper
// --------------------------------
void() SUB_ImpulseCommands =
{
	if (!self.impulse) return;

	//truck mod just this check
	if (self.flags & FL_VEHICLE) {
		if (self.impulse <= 4)
			return; //truck impulses in m_truckmod.qc
	}

	if (self.impulse < 9)
	{
		W_ChangeWeapon();
	} else if (self.impulse >= 20 && self.impulse <= 39)
	{
		dev_impulse(self.impulse);
	} else switch (self.impulse)
	{
	case 10:
		CycleWeaponCommand();
		break;
	case 12:
		CycleWeaponReverseCommand();
		break;
	case 11:
		ServerflagsCommand();
		break;
	case 13:
		W_SelectBestShotgun();
		break;
	case 14:
		W_SelectBestNailgun();
		break;
	case 15:
		W_SelectBestWeapon();
		break;
	case 16:
		W_SelectLastWeapon();
		break;

	case 40:
		dev_impulse_list();
		break;
	case 64:
		dev_i_cant_see();
		break;
	case 72:
		dev_test();
		break;
	case 80:
		dev_add_meatball();
		break;
	case 81:
		dev_remove_meatball();
		break;
	case 100:
		dev_invoke();
		break;
	case 101:
		dev_reveal();
		break;
	case 102:
		dev_trigger();
		break;
	case 103:
		dev_hitpoints();
		break;
	case 104:
		dev_serverflags();
		break;
	case 105:
		dev_warp();
		break;
	case 106:
		dev_whatami();
		break;
	case 108:
		dev_tracetest();
		break;
	case 127:
	case 129:
		coredump();
		break;

	case 140:
		sound(self, CHAN_VOICE, "player/tornoff2.wav", 1, ATTN_STATIC);
		centerprint(self, version_s);
		break;

	case 9:
		Cheat_Items();
		break;
	case 99:
		Cheat_Keys();
		break;
		// how about, execute order six?
		// nah. makes it sound like there aren't that many orders
		case 66:
		case 205:
			if (!deathmatch && !coop)
				Cheat_Genocide();
			break;
		case 200:
			dev_remaining_monsters();
			break;
		case 210:
			toggle_autosave();
			break;
		case 215:
			Cheat_Undying();
			break;
		case 225:
			Cheat_Suit();
			break;
		case 235:
			Cheat_Pent();
			break;
		case 245:
			Cheat_Ring();
			break;
		case 255:
			Cheat_Quad();
			break;

		default:
			return;
		}
		self.impulse = 0;
}
/*
================================
BackpackTouch
================================
*/
void() SUB_BackpackTouch =
{
	//truck mod just this check
	if (other.flags & FL_VEHICLE)
		if (other.classname != "monster_truck")
			other = other.owner.driver;
		else other = other.driver;

	if (!CheckValidTouch()) return;

	// coop 1: players can only pick up their own backpacks
	//if (coop == 1 && self.buddy && self.buddy != other) return;
	// reverted:
	// with no good way to indicate whose backpack is whose (because .colormap
	// only works on players outside the original software renderer) this led to 
	// a lot of ignored mystery backpacks players kept obsessively touching.
	// going out of your way for your own ammo is also a waste of time unless
	// the level is extremely linear, which good quake levels never are

	float acount;

	other.ammo_shells = other.ammo_shells + self.ammo_shells;
	other.ammo_nails = other.ammo_nails + self.ammo_nails;
	other.ammo_rockets = other.ammo_rockets + self.ammo_rockets;
	other.ammo_cells = other.ammo_cells + self.ammo_cells;
	bound_ammo(other);
	armor_give(other, self.armorvalue, 0, FALSE);

	sprint(other, "You got ");

	if (self.items && (other.items & self.items) == 0)
	{
		acount = TRUE;
		other.items |= self.items;
		sprint(other, "the ");
		sprint(other, self.netname);

		// change to the weapon
		W_BetterWeapon(other, self.items);
	}

	if (self.armorvalue)
	{
		if (acount) sprint(other, ", ");
		acount = 1;
		sprint(other, ftos(self.armorvalue));
		sprint(other, " armor");
	}
	if (self.ammo_shells)
	{
		if (acount) sprint(other, ", ");
		acount = 2;
		print_quant(self.ammo_shells, "shell", other);
	}
	if (self.ammo_nails)
	{
		if (acount) sprint(other, ", ");
		acount = 2;
		print_quant(self.ammo_nails, "nail", other);
	}
	if (self.ammo_rockets)
	{
		if (acount) sprint(other, ", ");
		acount = 2;
		print_quant(self.ammo_rockets, "rocket", other);
	}
	if (self.ammo_cells)
	{
		if (acount) sprint(other, ", ");
		acount = 2;
		print_quant(self.ammo_cells, "cell", other);
	}

	sprint(other, "\n");

	// do this after because t_heal prints its own message
	if (self.healamount)
		T_Heal(other, self.healamount, 0);

	// regular monster backpacks don't make the AWESOME NEW backpack sound
	if (self.classname == "item_backpack")
	{
		if (acount == 2)
			sound(other, CHAN_ITEM, "items/pack.wav", 1, ATTN_NORM);
		else	// only got armor, play armor sound instead
			sound(other, CHAN_ITEM, "items/patch.wav", 1, ATTN_NORM);
	} else
		sound(other, CHAN_ITEM, "weapons/lock4.wav", 1, ATTN_NORM);

	stuffcmd(other, "bf\n");

	if ((coop == 1 && self.buddy && self.buddy == other)
		|| (!other.weapon))
		SUB_CallAsSelf(W_SelectBestWeapon, other);
	else
		SUB_CallAsSelf(W_SetCurrentAmmo, other);
	ItemTouched();
}
/*
============
ammo_touch
============
*/
void() SUB_ammo_touch =
{
	//truck mod just this check
	if (other.flags & FL_VEHICLE)
		if (other.classname != "monster_truck")
			other = other.owner.driver;
		else other = other.driver;

	if (!CheckValidTouch()) return;

	// structured in dual if's instead of using && to preserve ammo_touch maphacks
	if (self.ammo_shells)
	{
		if (other.ammo_shells < MAX_AMMO_SHELLS)
			other.ammo_shells += self.ammo_shells;
		else return;
	} else if (self.ammo_nails)
	{
		if (other.ammo_nails < MAX_AMMO_NAILS)
			other.ammo_nails += self.ammo_nails;
		else return;
	} else if (self.ammo_rockets)
	{
		if (other.ammo_rockets < MAX_AMMO_ROCKETS)
			other.ammo_rockets += self.ammo_rockets;
		else return;
	} else if (self.ammo_cells)
	{
		if (other.ammo_cells < MAX_AMMO_CELLS)
			other.ammo_cells += self.ammo_cells;
		else return;
	}
	//else return;	

	bound_ammo(other);

	sprint(other, "You got the ");
	sprint(other, self.netname);
	sprint(other, "\n");

	sound(other, CHAN_ITEM, "weapons/lock4.wav", 1, ATTN_NORM);
	stuffcmd(other, "bf\n");

	if (!self.weapon)
		SUB_CallAsSelf(W_SelectBestWeapon, other);
	else
		// if changed current ammo, update it	
		SUB_CallAsSelf(W_SetCurrentAmmo, other);

	ItemTouched();
}

/*
=============
weapon_touch
=============
*/
void() SUB_weapon_touch =
{
	float	leave, nsw;

	//truck mod just this check
	if (other.flags & FL_VEHICLE)
		if (other.classname != "monster_truck")
			other = other.owner.driver;
		else other = other.driver;

	if (!CheckValidTouch()) return;

	if (deathmatch == 2 || deathmatch == 3 || coop > 1)
		leave = 1;
	else
		leave = 0;

	if (leave)
	{
		if (other.items & self.items == self.items)	// already have it
		{
			weapon_touch_coop();
			return;
		}
	}

	if (self.items & other.items) nsw = TRUE;

	weapon_give(other);
	// change to the weapon
	if (nsw)
		SUB_CallAsSelf(W_ResetWeaponState, other);
	else
		W_BetterWeapon(other, self.items);

	if (coop == 1)
	{
		entity pl = get_next_client(other);
		while (pl != other)
		{
			weapon_give(pl);
			pl = get_next_client(pl);
		}
	}

	if (leave)
	{
		weapon_touch_coop();
		return;
	}

	ItemTouched();
}

/*
================
PlayerPreThink

Called every frame before physics are run
================
*/
void() SUB_PlayerPreThink =
{
	if (initCleanup)
	{
		fog_setFromEnt(self, self);
		if (!(self.customflags & (CFL_PLUNGE | CFL_LIMBO)))
		{
			TintScreen(self, 0);
		} else if (self.customflags & CFL_LIMBO)
		{
			TintScreen(self, 255);
		}
	}

	if (intermission || self.deadflag == DEAD_SPECTATING)
	{
		IntermissionThink();	// otherwise a button could be missed between
		return;					// the think tics
	}
	makevectors(self.v_angle);		// is this still used
									// lunaran: "yes"

	CheckRules();

	if (self.deadflag >= DEAD_DEAD)
	{
		PlayerDeathThink();
		return;
	}

	if (self.deadflag == DEAD_DYING)
		return;	// dying, so do nothing

	self.wait = 0;

	PlayerWaterTest();
	WaterMove();
	if (self.waterlevel == WL_WAIST)
		CheckWaterJump();

	//truckmod just this check ======================================================
	if !(self.flags & FL_VEHICLE) {
		if (self.button2)
		{
			PlayerJump();
		} else
		{
			self.flags = self.flags | FL_JUMPRELEASED;
		}
	}

	// teleporters can force a non-moving pause time	
		if (time < self.pausetime)
			self.velocity = '0 0 0';

		if (time > self.attack_finished &&
			!W_HasAmmo(self.weapon) &&
			self.weapon != IT_AXE
			)
		{
			W_SelectBestWeapon();
		}

		if (self.movetype == MOVETYPE_NOCLIP)
		{
			self.flags = self.flags | FL_FLY;
		}

		// ai_nav
		//nav_editorThink();
}
/*
===========
FindTarget

Self is currently not attacking anything, so try to find a target

Returns TRUE if an enemy was sighted

When a player fires a missile, the point of impact becomes a fakeplayer so
that monsters that see the impact will respond as if they had seen the
player.
============
*/
float() SUB_FindTarget =
{
	local entity	client;
	local float		r;

	//dprint("in findtarget\n");
	// (spawnflags & 3) unhacked by lunaran since I actually want to use spawnflag 2 for something
	// apparently all the mega-enforcers in lunsp1 were ambush because of this ... oops
	if (sight_entity_time >= time - 0.1 && (!(self.spawnflags & SPAWN_AMBUSH)))
	{
		client = sight_entity;
		if (client.enemy == self.enemy)
			return FALSE;
	} else
	{
		// to avoid spending too much time, only check a single client (or fakeclient)
		// this means multiplayer games have slightly slower noticing monsters
		client = checkclient();
		if (!client)
			return FALSE;	// no check entities in PVS
	}

	if (client == self.enemy)
		return FALSE;

	if (!FilterTarget(client))
		return FALSE;
	if (client.classname != "player" && !FilterTarget(client.enemy))
		return FALSE;	// don't wake up other monsters in notarget mode

	if (!visible(client))
		return FALSE;

	r = range(client);

	if (r == RANGE_NEAR)
	{
		if (client.show_hostile < time && !infront(client))
			return FALSE;
	} else if (r == RANGE_MID || r == RANGE_FAR)
	{
		if (!infront(client))
			return FALSE;
	}

	// the only two things that alert monsters when invisible besides damage:
	// - firing a weapon
	// - bumping into a dog
	if (has_invis(client))
	{
		if (!(r == RANGE_MELEE && self.classname == "monster_dog" && client.classname == "player"))
		{
			if (client.show_hostile < time)
				return FALSE;
			if (r == RANGE_FAR)
				return FALSE;
		}
	}

	// got one
	self.enemy = client;
	if (self.enemy.classname != "player")
	{
		self.enemy = self.enemy.enemy;	// angered by a monster angering, use its enemy
		if (self.enemy.classname != "player")
		{
			self.enemy = world;
			return FALSE;
		}
	}
	//truckmod just this check
	if (self.enemy.flags & FL_VEHICLE) {
		local entity truck = self.enemy.owner;
		local entity gunner = truck.turret;
		if !(gunner.enemy) {
			gunner.enemy = self;
			dprint("findtarget force turret e\n");}
		self.enemy = truck.driver; //target the fake player
		if !(alive(self.enemy)) {
			dprint("findtarget dead driver\n");
			return FALSE;}
		dprint("FL_VEHICLE FindTarget FoundTarget\n");
	}
	FoundTarget();

	return TRUE;
}