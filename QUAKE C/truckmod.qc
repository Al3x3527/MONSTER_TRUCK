//====================================
//DEFS
//====================================

float FL_VEHICLE = 131072;
float I_AM_TURRET = 262144; //dumptruck_ds
.entity driver;
.entity passenger;
.entity turret;

.entity wheel1, wheel2, wheel3, wheel4;

.vector flyhack;

// --------------------------------
// ImpulseCommands --Copper
// --------------------------------
void() ImpulseCommands =
{
	if (!self.impulse) return;

	if (self.flags & FL_VEHICLE) {
		if (self.impulse <= 3)
			return;
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
============================================================

Monster_Truck

============================================================
*/

//forwards
$frame forward1 forward2
//right
$frame right1 right2
//left
$frame left1 left2

//try to walkmove if on ground, call traceline if flying
void() cpywalk =
{
	local vector delta, deltay, deltax1, deltax2, deltaz;
	local float dist, yaw;
	local vector avec = self.owner.avelocity;
	local vector fakeangles = self.owner.angles;
	fakeangles.x = -fakeangles.x;
	makevectors(fakeangles);
	local vector view = self.view_ofs + self.owner.view_ofs;
	view = view.x * v_forward + view.y * v_right + view.z * v_up + self.owner.origin;
	//from origin
	local vector del = self.owner.origin - self.origin;
	//from angular
	deltay = avec.y * 0.1 * (6.28 / 360) * ((del * v_forward) * v_right + (del * v_right) * v_forward);
	deltax1 = -avec.x * 0.628 / 360 * (del * v_forward) * v_up;
	deltax2 = -avec.x * 0.628 / 360 * (del * v_up) * v_forward;
	deltaz = -avec.z * 0.628 / 360 * ((del * v_right) * v_up + (del * v_up) * v_right);
	//from velocity
	delta = deltay + deltax1 + deltax2 + deltaz + self.owner.velocity * 0.1;
	//actual delta
	delta = delta + view - self.origin;
	dist = vlen(delta);

	local vector dang = self.owner.angles + self.v_angle - self.angles;
	if (dang.y > 180) dang.y = -360 + dang.y;
	else if (dang.y < -180) dang.y = 360 + dang.y;
	self.avelocity = dang * 10;

	if (dist > 100) {
		dprint("cpywalk setorigin\n");
		setorigin(self, view);
		self.velocity = self.owner.velocity;
		return;
	}
	if ((self.movetype == MOVETYPE_STEP) && (self.flags & FL_ONGROUND)) {
		yaw = vectoyaw(delta);
		walkmove(yaw, dist);
		} else if (self.solid == SOLID_BBOX) {
		traceline(self.origin, delta, TRUE, self);
		if (trace_fraction) {
			delta = delta * trace_fraction;
			} else delta = '0 0 0';
	}
	self.velocity = delta * 10;
};

//limit x,y
vector(vector given, vector limit) xylimit =
{
	//dprint("xy limit\n");
	//dprint(vtos(given));
	//dprint(" given in\n");

		if !(limit)
			return limit;
		if !(given)
			return given;

		if (limit.x > 0) {
			if (limit.x < given.x)
				given.x = limit.x;
			else if (given.x < -limit.x)
				given.x = -limit.x;
				} else if (limit.x > given.x)
			given.x = limit.x;
		else if (limit.x > -given.x)
			given.x = -limit.x;

		if (limit.y > 0) {
			if (limit.y < given.y)
				given.y = limit.y;
			else if (given.y < -limit.y)
				given.y = -limit.y;
		} else if (limit.y > given.y)
				given.y = limit.y;
		else if (limit.y > -given.y)
			given.y = -limit.y;
		//dprint(vtos(given));
		//dprint(" return\n");
			return given;
}

//vector control x,y
vector(vector set, vector sys, float k) xycontrol =
{
	set.z = 0;
	if !(set)
		return set;
	if !(sys)
		return set;

	if (set.x > 0) {
		if (set.x < sys.x) {
			if (set.x < (sys.x - set.x))
				set.x = ((set.x - sys.x) * k) - set.x;
			else set.x = ((sys.x - set.x) - sys.x) * k + (set.x - sys.x);
			//dprint("vcontrol x\n");
		}
	} else {
		if (set.x > sys.x) {
			if (set.x > (sys.x - set.x))
				set.x = ((set.x - sys.x) * k) - set.x;
			else set.x = ((sys.x - set.x) - sys.x) * k + (set.x - sys.x);
			//dprint("vcontrol -x\n");
		}
	}
	if (set.y > 0) {
		if (set.y < sys.y) {
			if (set.y < (sys.y - set.y))
				set.y = ((set.y - sys.y) * k) - set.y;
			else set.y = ((sys.y - set.y) - sys.y) * k + (set.y - sys.y);
			//dprint("vcontrol y\n");
		}
	} else {
		if (set.y > sys.y) {
			if (set.y > (sys.y - set.y))
				set.y = ((set.y - sys.y) * k) - set.y;
			else set.y = ((sys.y - set.y) - sys.y) * k + (set.y - sys.y);
			//dprint("vcontrol -y\n");
		}
	}
	return set;
}

//set: full extension, sys: actual deflection, c: damping ratio
float(float sys, float set, float c) zcontrol =
{

	if !(sys)
		return sys;

	if (sys > 0) { //deflect up
		if (sys > set)  //full deflection
			sys = sys - (sys - set) * c;
		else //partial deflection
			sys = sys * c;
	} else {
		if (sys < -set) //full
			sys = sys + (sys + set) * c;
		else
			sys = sys * c;
	}
	sys = sys * 0.1;
	return sys;
}

/*void() truck_atk =
{
	local vector	dir;
	local entity gunner = self.owner.turret;
	sound(self, CHAN_WEAPON, "weapons/spike2.wav", 1, ATTN_NORM);
	self.attack_finished = time + 0.2;
	dir = aim(self, 1000);
	launch_spike(gunner.origin + '0 0 30', dir);
	newmis.touch = superspike_touch;
	setmodel(newmis, "progs/laser.mdl");
	setsize(newmis, VEC_ORIGIN, VEC_ORIGIN);
	self.punchangle_x = -2;
}*/

//calculate vehicle_truck velocity and avelocity from wheels
float (float dist, vector dir) truck_physics =
{
	local vector vec1, vec2, vec3, vec4;
	local entity truck = self;

	//=================================================================
	//steer and throttle inputs 
	//=================================================================
	
	//truck vectors - velocity from wheels vs gravity, est grip
	local vector svec = truck.velocity;
	local vector avec = truck.avelocity;
	local vector tvec = svec * 0.025;
	local float throttle = 1;
	local float fakedist = dist;
	if !(dist) {
		throttle = -1;
		fakedist = vlen(tvec)/4;
		}

	local vector fakeangles = truck.angles;
	fakeangles.x = -fakeangles.x;
	makevectors(fakeangles); //starting angles

	local float steer_yaw = vectoyaw(dir);
	local float deflection = 3;
	local float damping = 0.6;

	//=================================================================
	//front wheels work against momentum
	//=================================================================
	   
	//ideal work against momentum
	//front wheels
	self = truck.wheel1; //virtual
	if ((self.velocity.z == 0) && !(self.flags & FL_ONGROUND)) self.flags = self.flags + FL_ONGROUND;
	local vector view = self.view_ofs;
	view = v_forward * view.x + v_right * view.y + v_up * view.z + truck.origin; //start from the resting position
	self.flyhack.z = self.origin.z - view.z;
	setorigin (self, view);  //make reset after finding delta
	walkmove(steer_yaw, fakedist); //movetype_step physics
	vec1 = self.origin - view; //get to current position from start position
	vec1.z = self.flyhack.z;
	if (vlen(vec1) < (0.9 * fakedist)){ 
	//dprint("short step\n");
	vec1 = self.flyhack;}//probably accomplishing nothing.
	vec1.z = zcontrol(vec1.z, deflection, damping); //damped spring ratio
	if (self.flags & FL_ONGROUND) self.flags = self.flags - FL_ONGROUND;
	self.velocity.z = vec1.z - 65; //for next think
	//gravity over 65 causes constant "dddddddd" sounds

	self = truck.wheel2;
	if ((self.velocity.z == 0) && !(self.flags & FL_ONGROUND)) self.flags = self.flags + FL_ONGROUND;
	view = self.view_ofs;
	view = v_forward * view.x + v_right * view.y + v_up * view.z + truck.origin;
	self.flyhack.z = self.origin.z - view.z;
	setorigin(self, view);
	walkmove(steer_yaw, fakedist);
	vec2 = self.origin - view;
	vec2.z = self.flyhack.z;
	if (vlen(vec2) < (0.9 * fakedist)) {
		//dprint("short step\n");
		vec2 = self.flyhack;
	}
	vec2.z = zcontrol(vec2.z, deflection, damping);
	if (self.flags & FL_ONGROUND) self.flags = self.flags - FL_ONGROUND;
	self.velocity.z = vec2.z - 65;
	
	//=================================================================
	//change in rear wheels velocity
	//=================================================================

	local vector pivot = (truck.wheel1.origin + truck.wheel2.origin) * 0.5;
	pivot.z = pivot.z - truck.wheel1.view_ofs.z; //level with vehicle
	local vector chassis_vec = pivot - truck.origin; //delta (forward vec)
	local float chassis_yaw = vectoyaw(chassis_vec); //new truck yaw

	local float dang;
	local float reverse = -1;
	dang = steer_yaw - chassis_yaw;
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	if ((dang > 90) || (dang < -90)) {
		chassis_yaw = chassis_yaw - 180;
		reverse = 1;}

	//rear wheels
	self = truck.wheel3;
	if ((self.velocity.z == 0) && !(self.flags & FL_ONGROUND)) self.flags = self.flags + FL_ONGROUND;
	view = self.view_ofs;
	view = v_forward * view.x + v_right * view.y + v_up * view.z + truck.origin;
	self.flyhack.z = self.origin.z - view.z;
	setorigin(self, view);
	walkmove(chassis_yaw, fakedist); //move from view
	vec3 = self.origin - view; //movestep delta
	vec3.z = self.flyhack.z;
	vec3.z = zcontrol(vec3.z, deflection, damping);
	if (self.flags & FL_ONGROUND) self.flags = self.flags - FL_ONGROUND;
	self.velocity.z = vec3.z - 65;

	self = truck.wheel4;
	if ((self.velocity.z == 0) && !(self.flags & FL_ONGROUND)) self.flags = self.flags + FL_ONGROUND;
	view = self.view_ofs;
	view = v_forward * view.x + v_right * view.y + v_up * view.z + truck.origin;
	self.flyhack.z = self.origin.z - view.z;
	setorigin(self, view);
	walkmove(chassis_yaw, fakedist);
	vec4 = self.origin - view;
	vec4.z = self.flyhack.z;
	vec4.z = zcontrol(vec4.z, deflection, damping);
	if (self.flags & FL_ONGROUND) self.flags = self.flags - FL_ONGROUND;
	self.velocity.z = vec4.z - 65;

	//=================================================================
	//vehicle forces, target vector
	//=================================================================
	//all fake wheels are in ideal locations and ideal velocities have been calculated for each wheel

	//grip
	local float fgrip;
	local float rgrip = 0.6;
	local float sgrip = 0.5;

	if (dist)
		fgrip = dist;
	else fgrip = rgrip;
	
	chassis_vec = normalize(chassis_vec);
	local vector grip1, grip2, grip3, grip4;
	grip1 = normalize(vec1) * fgrip + v_right * rgrip;
	grip2 = normalize(vec2) * fgrip + v_right * rgrip;
	grip3 = v_forward * fgrip + v_right * rgrip;
	grip4 = v_forward * fgrip + v_right * rgrip;

	if (vec1.z < -1)
		grip1 = '0 0 0';
	else {
		grip1 = (1 - vec1.z) * grip1; //mu*m*svec1.z^2
		vec1.z = vec1.z - tvec.z;
		}
	if (vec2.z < -1)
		grip2 = '0 0 0';
	else {
		grip2 = (1 - vec2.z) * grip2;
		vec2.z = vec2.z - tvec.z;
		}
	if (vec3.z < -1)
		grip3 = '0 0 0';
	else {
		grip3 = (1 - vec3.z) * grip3;
		vec3.z = vec3.z - tvec.z;
		}
	if (vec4.z < -1)
		grip4 = '0 0 0';
	else {
		grip4 = (1 - vec4.z) * grip4;
		vec4.z = vec4.z - tvec.z;
		}
	
	local vector work1 = vec1;	work1.z = 0;
	work1 = xylimit(work1, grip1) * throttle;
	local vector control1 = xycontrol(work1, tvec, sgrip);
	work1.z = vec1.z;
	truck.wheel1.flyhack = work1;
	control1 = control1 + work1;
	work1.z = work1.z * throttle;

	local vector work2 = vec2;	work2.z = 0;
	work2 = xylimit(work2, grip2) * throttle;
	local vector control2 = xycontrol(work2, tvec, sgrip);
	work2.z = vec2.z;
	truck.wheel2.flyhack = work2;
	control2 = control2 + work2;
	work2.z = work2.z * throttle;

	local vector work3 = vec3;	work3.z = 0;
	work3 = xylimit(work3, grip3) * throttle;
	local vector control3 = xycontrol(work3, tvec, sgrip);
	work3.z = vec3.z;
	truck.wheel3.flyhack = work3;
	control3 = control3 + work3;
	work3.z = work3.z * throttle;

	local vector work4 = vec4;	work4.z = 0;
	work4 = xylimit(work4, grip4) * throttle;
	local vector control4 = xycontrol(work4, tvec, sgrip);
	work4.z = vec4.z;
	truck.wheel4.flyhack = work4;
	control4 = control4 + work4;
	work4.z = work4.z * throttle;

	//actual travel
	svec = (svec + ((control1 + control2 + control3 + control4) * 10));

	local vector final_vec = v_forward + (work1 + work2 - work3 - work4) * throttle;
	local vector final_angs = vectoangles(final_vec);

	dang = final_angs.x - truck.angles.x;
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	avec.x = ((dang) * 1);

	dang = (final_angs.y - truck.angles.y);
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	avec.y = ((dang) * 1);
	local float final_yaw = vectoyaw(final_vec);

	final_vec = v_right + (-work1 - work3 + work2 + work4) * throttle;
	final_angs = vectoangles(final_vec);

	dang = (final_angs.x - truck.angles.z);
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	avec.z = ((dang) * 1);

	local float start_yaw = truck.angles.y;
	//dprint("\n");
	//dprint(vtos(dir));
	//dprint(" dir\n");
	//dprint(vtos(chassis_vec));
	//dprint(" chassis vec\n");
	//dprint(vtos(final_angs));
	//dprint(" final angs\n");
	//dprint(ftos(final_yaw));
	//dprint(" final yaw\n");
	//dprint(ftos(dang));
	//dprint(" dang\n");
	//dprint(ftos(steer_yaw));
	//dprint(" steer yaw\n");
	//dprint(ftos(start_yaw);
	//dprint(" start yaw\n");
	//dprint(vtos(truck.angles));
	//dprint(" start angles\n");
	//dprint(vtos(avec));
	//dprint(" avec\n");

	//=================================================================
	//vehicle velocity, avelocity
	//=================================================================

	//move chassis
	truck.avelocity = avec;
	truck.velocity = svec;

	//fix stuck
	if ((truck.flags & FL_ONGROUND) && (truck.origin.z < (truck.height + (truck.velocity.z * 0.025))))
	{ 
		truck.velocity.z = 0;
		setorigin(truck, truck.origin + '0 0 18');
		setorigin(truck.wheel1, truck.wheel1.origin + '0 0 16');
		setorigin(truck.wheel2, truck.wheel2.origin + '0 0 16');
		setorigin(truck.wheel3, truck.wheel3.origin + '0 0 16');
		setorigin(truck.wheel4, truck.wheel4.origin + '0 0 16');
		truck.flags = truck.flags - FL_ONGROUND;
		dprint("truck stuck fix\n");
		}
	
	truck.height = truck.origin.z;
	truck.flyhack = truck.velocity;

	truck.ideal_yaw = final_yaw;
	//dprint(vtos(truck.velocity));
	//dprint("truck velocity\n");

	self = truck;
	ChangeYaw();

	//animate
	local float direction;
	dang = -steer_yaw + start_yaw;
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	if ((dang > 15) && (dang < 165))
		direction = 1; //right
	else if ((dang < -15) && (dang > -165))
		direction = -1; //left
	//else 0;
	direction = direction * -reverse;
	return direction;
};

void(entity truck) spawn_truck_driver =
{
	local entity player = self;
	local entity pilot = spawn();
	self = pilot;

	player.driver = pilot;
	pilot.owner = truck;
	setmodel(self, "progs/player.mdl");
	setsize(self, '-10 -10 0', '10 10 60');
	self.view_ofs = '10 -15 40';
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;
	self.health = 1;

	setorigin(self, truck.origin); //fix next truck think
	self = player;
}

//orbital camera
void(vector dir, vector offset) camera_orbit =
{
	local vector delta;
	local float dist;
	local entity truck = self.owner;
	local vector avec = truck.avelocity;
	local vector fakeangles = truck.angles;
	fakeangles.x = -fakeangles.x;
	makevectors(fakeangles);
	local vector view = dir * offset.x;
	view.z = view.z + offset.z;
	local vector newangles = vectoangles(view);
	view = view + truck.origin;
	//from origin
	local vector del = truck.origin - self.origin;
	//from velocity of focus
	delta = truck.velocity * 0.1;
	//actual delta
	delta = delta + view;
	delta = delta - self.origin;
	dist = vlen(delta);

	local vector dang = newangles - self.angles;
	if (dang.y > 180) dang.y = -360 + dang.y;
	else if (dang.y < -180) dang.y = 360 + dang.y;
	self.avelocity = (dang * 10 * 4 + self.avelocity) / 5;

	if (dist > 200) {
		//dprint("cpywalk setorigin\n");
		setorigin(self, view);
		self.velocity = truck.velocity;
		return;
	}
	self.velocity = (delta * 10 * 4 + self.velocity) / 5;

	//dismount here because we have angles
	if (self.impulse == 1) {
		self.impulse = 0;
		setmodel(self, self.model);
		self.movetype = MOVETYPE_WALK;
		view = v_forward * 10 - v_right * 50 + v_up * 40;
		setorigin(self, truck.origin + view);
		self.velocity = truck.velocity;
		self.flags = self.flags - FL_VEHICLE;
		sprint(self, "Truck dismounted\n");
		truck.driver = world;
		self.owner = world;
		cvar_set("cl_bob", "0.02");
		cvar_set("cl_rollangle", "2");
		self.driver.health = 0;
		remove(self.driver);
		//switch_weapon(self.weapon1);
	}
}

void() truck_jump =
{
	if (self.count > time)
		return;
	self.count = time + 0.5;
	self.owner.velocity.z = self.owner.flyhack.z = self.owner.velocity.z + 270;
self.owner.wheel1.origin.z = self.owner.wheel1.origin.z + 270;
self.owner.wheel2.origin.z = self.owner.wheel2.origin.z + 270;
self.owner.wheel3.origin.z = self.owner.wheel3.origin.z + 270;
self.owner.wheel4.origin.z = self.owner.wheel4.origin.z + 270;
}

void() truck_boost =
{
	if (self.cnt > time)
		return;
	self.cnt = time + 0.5;
	makevectors(self.owner.angles);
	self.owner.velocity = self.owner.velocity + 1000 * v_forward;
}

//other impulse commands
void() truck_ImpulseCommands =
{
	if (self.impulse == 1)
		return; //in camera
	if (self.impulse == 2)
		truck_jump();
	if (self.impulse == 3)
		truck_boost();

	self.impulse = 0;
}

vector () truck_pilot =
{
	local entity truck = self;
	self = other;

if !(self.driver.health) {
	self.modelindex = 0;
	self.weaponmodel = string_null;
	self.movetype = MOVETYPE_FLY;
	self.owner = truck;
	cvar_set("cl_bob", "0");
	cvar_set("cl_rollangle", "0");
	spawn_truck_driver(truck);
	//switch_weapon(truck);
	sprint(self, "Press 1 to Dismount\nPress 2 to Jump\nPress 3 to Boost\n");
	}
	local vector dir = aim(world, 1000);
	local vector offset = '-200 0 60';
	camera_orbit(dir, offset);
	truck_ImpulseCommands();
	self = truck;
	return (dir);
}

void() truck_drive = [ $forward1, truck_drive ]
{
	local float dist = 0;
	if (self.driver) {
		other = self.driver;
		if (other.button2)
			dist = 4;
		local vector dir = truck_pilot();
	}	//chassis physics / prethink
	local float direction = truck_physics(dist, dir);

	if (self.walkframe > 1)
		self.walkframe = 0;
	if !(direction)
		self.frame = $forward1 + self.walkframe;
	else if (direction == 1)
		self.frame = $right1 + self.walkframe;
	else 
		self.frame = $left1 + self.walkframe;
	if (dist)
		self.walkframe = self.walkframe + 1;
	local entity truck = self;
	self = self.turret;
	cpywalk();
	self = truck.passenger;
	cpywalk();
	if (other) {
		self = other.driver;
		cpywalk();
	}
};


void() truck_touch =
{
	if (!CheckValidTouch()) return;// from Copper -- dumptruck_ds

	if (!(other.flags & FL_CLIENT))
		return;
	if (self.driver == other) return;
	if (self.count < time) {
		sprint(other, "Press 1 to drive Truck\n");
		}
	self.count = time + 0.02;
	if (other.impulse == 1) {
		other.impulse = 0;
		self.driver = other;
		other.flags = other.flags + FL_VEHICLE;
		self.nextthink = time + 0.1;
		}
}

void() gunner_turret_atk1 = [0, gunner_turret_atk1]
{
	local entity player = self.owner.driver;
	if !(self.enemy)
		self.ideal_yaw = player.v_angle.y;
	self.v_angle.y = self.ideal_yaw - self.owner.angles.y;
	ChangeYaw();
};


//demo gunner
void() spawn_truck_gunner =
{
	local entity truck = self;
	local entity gunner = spawn();
	self = gunner;

	truck.turret = gunner;
	gunner.owner = truck;
	setmodel(self, "progs/player.mdl");
	setsize(self, '-10 -10 0', '10 10 60');
	self.view_ofs = '-70 0 50';
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;
	
	setorigin(self, truck.origin); //fix next truck think
	self.th_missile = gunner_turret_atk1;
	self.think = self.th_missile;
	self.nextthink = time + 0.1;
	self = truck;
}

void() spawn_truck_passenger =
{
	local entity truck = self;
	local entity shotgun = spawn();
	self = shotgun;

	truck.passenger = shotgun;
	shotgun.owner = truck;
	setmodel(self, "progs/player.mdl");
	setsize(self, '-10 -10 0', '10 10 60');
	self.view_ofs = '10 15 40';
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;

	setorigin(self, truck.origin); //fix next truck think
	self = truck;
}

//physics wheels
void(float i) spawn_truck_wheel =
{
	local entity truck = self;
	local entity wheel = spawn();
	self = wheel;
	self.movetype = MOVETYPE_STEP;
	self.owner = truck;
	self.solid = SOLID_TRIGGER;
	self.classname = "wheel";
	setsize(self, '-7 -7 -7', '7 7 7');
	if !(i) {
	truck.wheel1 = self;
	self.view_ofs = '70 35 7';
	}
	else if (i == 1) {
	truck.wheel2 = self;
	self.view_ofs = '70 -35 7';
	}
	else if (i == 2) {
	truck.wheel3 = self;
	self.view_ofs = '-70 35 7';
	}
	else if (i == 3) {
	truck.wheel4 = self;
	self.view_ofs = '-70 -35 7';
	}
	else dprint("too many wheels spawned!\n");
	setorigin(self, truck.origin + self.view_ofs);
	self = truck;
}

void() spawn_vehicle_truck =
{
	//body with wheels model
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;
	self.flags = FL_VEHICLE;
	setmodel(self, "progs/truck.mdl");
	setsize(self, '-112 -40 18', '112 40 80');
	self.classname = "monster_truck";

	//wheels -- not the visible model
	local float i = 0;
	while (i < 4)
	{
		spawn_truck_wheel(i);
		i++;
	}
	self.touch = truck_touch;
	self.think = truck_drive;

	//gunner
	if (self.spawnflags & I_AM_TURRET) {
		spawn_truck_gunner();
		spawn_truck_passenger();
		}
};

//Vanilla Spawning
void() vehicle_truck =
{
	precache_model("progs/truck.mdl");
	//if (SUB_Inhibit())
	//	return;
	spawn_vehicle_truck();
};


