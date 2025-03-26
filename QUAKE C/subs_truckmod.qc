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
