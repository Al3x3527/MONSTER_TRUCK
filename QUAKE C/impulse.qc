/*
==============================================================================

IMPULSES

==============================================================================
*/

// --------------------------------
// Cheat_Keys
// --------------------------------
void() Cheat_Keys =
{
	if(deathmatch || coop)
		return;

	key_give_silver(self);
	key_give_gold(self);
	stuffcmd(self,"bf\n");
}


// --------------------------------
// Cheat_Items
// --------------------------------
void() Cheat_Items =
{
	if(deathmatch || coop)
		return;

	self.ammo_shells = MAX_AMMO_SHELLS;
	self.ammo_nails = MAX_AMMO_NAILS;
	self.ammo_rockets = MAX_AMMO_ROCKETS;
	self.ammo_cells = MAX_AMMO_CELLS;
	
	self.items = self.items |
	//	IT_KEY1 | IT_KEY2 | 
		IT_AXE |
		IT_SHOTGUN |
		IT_SUPER_SHOTGUN |
		IT_NAILGUN |
		IT_SUPER_NAILGUN |
		IT_GRENADE_LAUNCHER |
		IT_ROCKET_LAUNCHER;

	self.items = self.items | IT_LIGHTNING;

	W_SetCurrentAmmo();
	W_Select(IT_ROCKET_LAUNCHER);

	stuffcmd(self,"bf\n");
}

// --------------------------------
// Cheat_Genocide
// --------------------------------
void() Cheat_Genocide =
{
	entity t;
	
	t = nextent(world);	
	while(t != world)
	{
		// these monsters haven't spawned yet, turn them into relays so their 
		// deathtargets fire as soon as they're triggered and their absence doesn't
		// break the level
		if(t.customflags & CFL_SPAWNER || t.spawnflags & SPAWN_TRIGGERED)
		{
			t.classname = "trigger_relay";
			t.count = 0;
			t.use = trigger_relay_use;
			t.spawnflags = 0;
		}
		t = nextent(t);
	}
	// kill existing monsters second, so that any monsters triggered by other monsters
	// are already de-monsterized
	t = nextent(world);
	while(t != world)
	{
		if(t.flags & FL_MONSTER)
		{
			// don't forget monsters on the verge of spawning
			if (t.think == mon_spawner_tryspawn || t.modelindex == 0 || t.classname == string_null )
				remove(t);
			else
				T_Damage(t, self, self, t.health, DMGTYPE_SCRIPT);		// waurgh
		}
		t = nextent(t);
	}
}

// --------------------------------
// Cheat_Undying
// --------------------------------
void() Cheat_Undying =
{
	if(deathmatch || coop)
		return;
	if(self.customflags & CFL_UNDYING)
	{
		sprint(self, "Undying mode disabled\n");
		self.customflags = not(self.customflags, CFL_UNDYING);
		return;
	}
	sprint(self, "Undying mode enabled\n");
	self.customflags |= CFL_UNDYING;
}


// --------------------------------
// Cheat_Quad
// --------------------------------
void() Cheat_Quad =
{
	if(deathmatch || coop)
		return;
	stuffcmd(self, "bf\n");
	self.items = self.items | IT_QUAD;
	powerup_super_damage(self, 30);
}

// --------------------------------
// Cheat_Pent
// --------------------------------
void() Cheat_Pent =
{
	if(deathmatch || coop)
		return;
	stuffcmd(self, "bf\n");
	self.items = self.items | IT_INVULNERABILITY;
	powerup_invulnerability(self, 30);
}

// --------------------------------
// Cheat_Ring
// --------------------------------
void() Cheat_Ring =
{
	if(deathmatch || coop)
		return;
	stuffcmd(self, "bf\n");
	self.items = self.items | IT_INVISIBILITY;
	powerup_invisibility(self, 30);
}

// --------------------------------
// Cheat_Suit
// --------------------------------
void() Cheat_Suit =
{
	if(deathmatch || coop)
		return;
	stuffcmd(self, "bf\n");
	self.items = self.items | IT_SUIT;
	powerup_envirosuit(self, 30);
}

// --------------------------------
// ServerflagsCommand
// --------------------------------
void() ServerflagsCommand =
{
	serverflags = serverflags * 2 + 1;
	dev_serverflags();
};

void() ImpulseCommands = {SUB_ImpulseCommands();}
