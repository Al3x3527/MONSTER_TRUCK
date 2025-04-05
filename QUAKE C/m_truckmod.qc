/*
============================================================

Monster_Truck

============================================================
known bugs:
* chance of elevator freakout, especially going up
X chance of camera freakout when gunner has an enemy
	X that is dead
	/ partially blocked by a wall 
	X findtarget force enemy loop
	/ shooting unsuspecting monster
	X when player can see monster around corner
		>should not be using aim() for this
* truck pulls to the left when low grip or in air
* stairstep accelerates up, even when coasting
* truck fix doesn't work on edges of platforms
X ai can't find each other sometimes
* truck clips too much into walls causing freakouts on elevators
* truck crabs a little when steering at a small angle
* truck sinks partially into elevator going down sometimes
* driving off edges sucks (boost helps)
	>raising bottom of monster_truck bbox helped

uniplemented ideas:
* a way for the truck and player to take damage (truck health as armor value?)
* mounted machinegun model and animations
* headlights and taillights
* engine sfx
* hostile monster_trucks
* truck collisions
* truck damage states
* truck death animations/explosions
* player use of other "seats"
* velocity based splatter damage
*/

//forwards
$frame forward1 forward2
//right
$frame right1 right2
//left
$frame left1 left2

//try to walkmove if on ground, call traceline if flying
void(float relative) cpywalk =
{
	local vector delta, deltay, deltax1, deltax2, deltaz;
	local float dist, yaw;
	local vector avec = self.owner.avelocity;
	local vector fakeangles = self.owner.angles;
	fakeangles.x = -fakeangles.x;
	makevectors(fakeangles);
	
	if ((self.flags & FL_ONGROUND) && (self.movetype & MOVETYPE_FLY))
		self.flags = self.flags - FL_ONGROUND; //this is dumb

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
	if !(relative) {
		local vector view = self.view_ofs + self.owner.view_ofs;
		view = view.x * v_forward + view.y * v_right + view.z * v_up + self.owner.origin;
		delta = delta + view - self.origin;
		}
	dist = vlen(delta);

	local vector dang = self.owner.angles + self.v_angle - self.angles;
	if (dang.y > 180) dang.y = -360 + dang.y;
	else if (dang.y < -180) dang.y = 360 + dang.y;
	self.avelocity = dang * 10;

	if (dist > 100) {
		//dprint("cpywalk setorigin\n");
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

//vector control damping
//call makevectors() first
vector(vector delta) vdamping =
{
	local float deflection = 3;
	local float c = 0.6;
	local vector sys = delta * v_up * v_up;
	local vector set = deflection * v_up;
	if !(set)
		return sys * 0.1 * c;
	if !(sys)
		return sys;
	local float speed = normalize(sys) * v_up; //positive or negative
	//dprint(ftos(speed)); dprint("speed\n");
	if (vlen(sys) > deflection)
		sys -= set * c * speed;
	else {
	sys *= c; 
	}
	//dprint(vtos(delta)); dprint("delta");
	//dprint(vtos(sys)); dprint("sys\n");
	sys *= 0.1;
	return sys;
};

vector(vector vec) notup =
{
	local vector vup = vec * v_up * v_up;
	vec = vec - vup;
	return vec;
}

vector (vector vec) up =
{
	vec = vec * v_up * v_up;
	return vec;
}

//grip control x,y,z
vector(vector work, vector tvec, vector dir, float mu) grip_control =
{
	local float speed;
	local vector grip;
	local vector lateral;
	tvec = notup(tvec);
	if !(dir) dir = v_forward;
	local vector fakedir = dir;
	if (work)
		fakedir = normalize(work);
	lateral_x = dir_y; lateral_y = -dir_x;
	local float active = 0;
	if (work) active = 1;
	//dprint(vtos(tvec)); dprint("tvec==============\n");
	//dprint(vtos(work)); dprint("work in"); dprint(ftos(mu)); dprint(" mu in\n");
if (mu)
{
	//SETUP
	//dprint(vtos(work)); dprint(" starting work\n");
	if !(mu <= 0) {
	speed = fakedir * dir; //for coasting only
	if (speed < 0) {
		speed = normalize(tvec) * dir;
		if (speed < 0) {
			work *= -1;
			}
		active = 0;
		}

	//USE ALL GRIP TO RESIST TVEC
	grip = -normalize(tvec);
	speed = vlen(tvec);
	if (mu > speed) {
		grip = - tvec; //grip to be used
	} else { 
	grip = mu * grip;
	}
	//dprint(vtos(grip)); dprint("grip used tvec\n");

	//RESTORE THE GRIP SPENT ALONG WORK VECTOR
	speed = fakedir * grip; //grip used in dir of work
	grip -= speed * fakedir; //grip used not in dir of work
	work += grip; //tvec grip
	//dprint(vtos(work)); dprint("work after lateral\n");
	mu -= vlen(grip);
	}

	if (active) { //powered wheels should work against dir in decel (dir backwards)
	work -= tvec; //only difference no runaway
	//dprint(vtos(work)); dprint("work after tvec"); dprint(ftos(mu)); dprint(" mu for full\n");
	speed = vlen(work);
	grip = normalize(work) * mu; //account for lateral

	if !(grip) mu = 0;
	else mu = vlen(grip);
}
}
	grip = tvec + work;
	//dprint(vtos(grip)); dprint("final vec\n");
	return work;
}
//=================================================================

//Truck Physics

//=================================================================

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
	//dprint(vtos(avec)); dprint("true avec\n");
	local vector tvec = svec * 0.025;
	local float throttle = 1;
	local float fakedist = dist;
	if !(dist) {
		throttle = -1;
		fakedist = vlen(tvec)/1.2;
		}

	local vector fakeangles = truck.angles;
	fakeangles.x = -fakeangles.x;
	makevectors(fakeangles); //starting angles

	local float steer_yaw = vectoyaw(dir);
	dir.z = 0;

	//animate
	local float start_yaw = truck.angles.y;
	local float dang;
	local float direction;
	dang = -steer_yaw + start_yaw;
	if (dang > 180) dang += -360;
	else if (dang < -180) dang += 360;
	if ((dang > 15) && (dang < 165))
		direction = 1; //right
	else if ((dang < -15) && (dang > -165))
		direction = -1; //left

	local float reverse = -1;
	//dang = steer_yaw - chassis_yaw;
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	if ((dang > 90) || (dang < -90)) {
		//chassis_yaw = chassis_yaw - 180;
		reverse = 1;
	}
	direction *= -reverse;

	//=================================================================
	//front wheels work against momentum
	//=================================================================

//differential stuff - front

	local float diff = 0;
	if (dist)
		diff = truck.wheel1.view_ofs.y * sin(90 - dang);
	local float fakediff = 0;
	local float dist1 = fakedist + diff * -direction; //differential effect
	if (dist1 < 0) {
		fakediff = -dist1;
		dist1 = 0;
		}
	else if (dist1 > fakedist) dist1 = fakedist;

	local float dist2 = fakedist + diff * direction + fakediff;
	if (dist2 < 0) {
		dist1 -= dist2;//left on the table
		dist2 = 0;
	} else if (dist2 > fakedist) dist2 = fakedist;
	//ideal work against momentum
	//front wheels
	self = truck.wheel1; //virtual
	if ((self.velocity.z == 0) && !(self.flags & FL_ONGROUND)) self.flags = self.flags + FL_ONGROUND;
	local vector view = self.view_ofs;
	
	view = v_forward * view.x + v_right * view.y + v_up * view.z + truck.origin; //start from the resting position
	local vector delta = self.origin - view;
	local vector fakeview = delta * v_up * v_up + view;
	setorigin (self, fakeview);  //make reset after finding delta
	walkmove(steer_yaw, dist1); //movetype_step physics
	vec1 = notup(self.origin - fakeview); //get to current position from start position
	local vector work1 = vec1;
	delta -= 10 * tvec;
	vec1 = vec1 + vdamping(delta);
	if (self.flags & FL_ONGROUND) self.flags = self.flags - FL_ONGROUND;
	traceline2(self.origin, self.origin - '0 0 8', self, 1); //detect moving platform
	if (trace_ent != world) {
		self.velocity = trace_ent.velocity; //not discrete
		vec1 -= trace_ent.velocity * 0.1;
		}
	view -= truck.origin;

	local vector tvec1 = svec
	+ avec.y * 0.628 / 360 * (view_x * v_right + view_y * v_forward)
	- avec.x * 0.628 / 360 * (view_x * v_up - view_z * v_forward)
	- avec.z * 0.628 / 360 * (view_y * v_up + view_z * v_right);
	tvec1 *= 0.025;

	self = truck.wheel2;
	if ((self.velocity.z == 0) && !(self.flags & FL_ONGROUND)) self.flags = self.flags + FL_ONGROUND;
	view = self.view_ofs;
	
	view = v_forward * view.x + v_right * view.y + v_up * view.z + truck.origin;
	delta = self.origin - view;
	fakeview = up(delta) + view;
	setorigin(self, fakeview);
	walkmove(steer_yaw, dist2);
	vec2 = notup(self.origin - fakeview);
	local vector work2 = vec2;
	delta -= 10 * tvec;
	vec2 += vdamping(delta);
	if (self.flags & FL_ONGROUND) self.flags = self.flags - FL_ONGROUND;
	traceline2(self.origin, self.origin - '0 0 8', self, 1); //detect moving platform
	if (trace_ent != world) {
		self.velocity = trace_ent.velocity;
		vec2 -= trace_ent.velocity * 0.1;
	}
	local vector tvec2 = svec
		+ avec.y * 0.628 / 360 * (view_x * v_right + view_y * v_forward)
		- avec.x * 0.628 / 360 * (view_x * v_up - view_z * v_forward)
		- avec.z * 0.628 / 360 * (view_y * v_up + view_z * v_right);
		tvec2 *= 0.025;

	//=================================================================
	//change in rear wheels velocity
	//=================================================================

	local vector pivot = (truck.wheel1.origin + truck.wheel2.origin) * 0.5;
	pivot.z = pivot.z - truck.wheel1.view_ofs.z; //level with vehicle
	local vector chassis_vec = pivot - truck.origin; //delta (forward vec)
	local float chassis_yaw = vectoyaw(chassis_vec * -reverse); //new truck yaw
	//local float chassis_yaw = fakeangles.y;
	dang = -chassis_yaw + start_yaw;
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	if (dist)
		diff = truck.wheel1.view_ofs.y * sin(90 - dang);
	else diff = 0;

	fakediff = 0;
	local float dist3 = fakedist + diff * -direction;
	if (dist3 < 0) {
		fakediff = -dist3;
		dist3 = 0;
	} else if (dist3 > fakedist) dist3 = fakedist;

	local float dist4 = fakedist + diff * direction + fakediff;
	if (dist4 < 0) {
		dist3 -= dist4;
		dist4 = 0;
	} else if (dist4 > fakedist) dist4 = fakedist;

	//rear wheels
	self = truck.wheel3;
	if ((self.velocity.z == 0) && !(self.flags & FL_ONGROUND)) self.flags = self.flags + FL_ONGROUND;
	view = self.view_ofs;
	
	view = v_forward * view.x + v_right * view.y + v_up * view.z + truck.origin;
	delta = self.origin - view;
	fakeview = up(delta) + view;
	setorigin(self, fakeview);
	walkmove(chassis_yaw, dist3); //move from view
	vec3 = notup(self.origin - fakeview); //movestep delta
	local vector work3 = vec3;
	delta -= 10 * tvec;
	vec3 += vdamping(delta);
	if (self.flags & FL_ONGROUND) self.flags = self.flags - FL_ONGROUND;
	traceline2(self.origin, self.origin - '0 0 8', self, 1); //detect moving platform
	if (trace_ent != world) {
		self.velocity = trace_ent.velocity;
		vec3 -= trace_ent.velocity * 0.1;
	}
	local vector tvec3 = svec
		+ avec.y * 0.628 / 360 * (view_x * v_right + view_y * v_forward)
		- avec.x * 0.628 / 360 * (view_x * v_up - view_z * v_forward)
		- avec.z * 0.628 / 360 * (view_y * v_up + view_z * v_right);
	tvec3 *= 0.025;

	self = truck.wheel4;
	if ((self.velocity.z == 0) && !(self.flags & FL_ONGROUND)) self.flags = self.flags + FL_ONGROUND;
	view = self.view_ofs;
	
	view = v_forward * view.x + v_right * view.y + v_up * view.z + truck.origin;
	delta = self.origin - view;
	fakeview = up(delta) + view;
	setorigin(self, fakeview);
	walkmove(chassis_yaw, dist4);
	vec4 = notup(self.origin - fakeview);
	local vector work4 = vec4;
	delta -= 10 * tvec;
	vec4 += vdamping(delta);
	if (self.flags & FL_ONGROUND) self.flags = self.flags - FL_ONGROUND;
	traceline2(self.origin, self.origin - '0 0 8', self, 1); //detect moving platform
	if (trace_ent != world) {
		self.velocity = trace_ent.velocity;
		vec4 -= trace_ent.velocity * 0.1;
	}
	local vector tvec4 = svec
		+ avec.y * 0.628 / 360 * (view_x * v_right + view_y * v_forward)
		- avec.x * 0.628 / 360 * (view_x * v_up - view_z * v_forward)
		- avec.z * 0.628 / 360 * (view_y * v_up + view_z * v_right);
	tvec4 *= 0.025;

	//Collider Tracelines
	chassis_vec = normalize(chassis_vec);
	self = truck;
	//check below for moving plat
	traceline2(self.origin + '0 0 20', self.origin - '0 0 3', self, 1); //origin is below bbox
	if (trace_ent != world)
		local vector vec5 = trace_ent.velocity; //touching ground velocity (as velocity)

	//=================================================================
	//vehicle forces, target vector
	//=================================================================

	//dprint(vtos(dir)); dprint("dir\n");
	//dprint(vtos(tvec)); dprint("true tvec\n");
	//dprint(vtos(work1)); dprint("work1\n");
	//dprint(vtos(work2)); dprint("work2\n");
	//dprint(vtos(work3)); dprint("work3\n");
	//dprint(vtos(work4)); dprint("work4\n");
	if (vlen(work1) > fakedist) work1 = normalize(work1) * fakedist;
	if (vlen(work2) > fakedist) work2 = normalize(work2) * fakedist;

	if !(throttle == -1) {
		work3 = '0 0 0';
		work4 = '0 0 0';
	}
	
	local float vup = -vec1 * v_up + 3;
	work1 = grip_control(work1, tvec, dir * throttle, vup);
	vup = -vec2 * v_up + 3;
	work2 = grip_control(work2, tvec, dir * throttle, vup);
	vup = -vec3 * v_up + 3;
	work3 = grip_control(work3, tvec, chassis_vec, vup);
	vup = -vec4 * v_up + 3;
	work4 = grip_control(work4, tvec, chassis_vec, vup);

	tvec = notup(tvec);
	work1 += up(vec1);
	truck.wheel1.flyhack = work1;

	work2 += up(vec2);
	truck.wheel2.flyhack = work2;

	work3 += up(vec3);
	truck.wheel3.flyhack = work3;

	work4 += up(vec4);
	truck.wheel4.flyhack = work4;

	//dprint(vtos(work1)); dprint("f work1\n");
	//dprint(vtos(work2)); dprint("f work2\n");
	//dprint(vtos(work3)); dprint("f work3\n");
	//dprint(vtos(work4)); dprint("f work4\n");
local vector work = work1 + work2 + work3 + work4;
//dprint(vtos(work)); dprint("total work\n");

	//actual travel
	svec = (svec + (work * 10));
	if (vec5)
		svec = notup(svec) + vec5;

	local vector final_vec = v_forward + (work1 + work2 - work3 - work4);
	local vector final_angs = vectoangles(final_vec);

	dang = final_angs.x - truck.angles.x;
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	avec.x = ((dang) * 1);

	local vector offsets = truck.wheel1.view_ofs;
	final_vec = (work1 + work2) * v_right * v_right + offsets_x * v_forward;
	final_vec -= (work3 + work4) * v_right * v_right - offsets_x * v_forward;
	final_vec += (work2 + work4) * v_forward * v_forward + offsets_y * v_right;
	final_vec -= (work1 +  work3) * v_forward * v_forward - offsets_y * v_right;

	dang = (final_angs.y - truck.angles.y);
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	avec.y = ((dang) * 1);
	local float final_yaw = vectoyaw(final_vec);

	final_vec = v_right + (-work1 - work3 + work2 + work4);
	final_angs = vectoangles(final_vec);

	dang = (final_angs.x - truck.angles.z);
	if (dang > 180) dang = -360 + dang;
	else if (dang < -180) dang = 360 + dang;
	avec.z = ((dang) * 1);

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
	setsize(self, '-10 -10 0', '10 10 30');
	if (truck.classname == "vehicle_truck")
		self.view_ofs = '10 -15 40';
	else self.view_ofs = '5 -7 20';
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;
	self.health = 1; //triggers doors
	setorigin(self, truck.origin + self.view_ofs); //fix next truck think
	self = player;
}

//orbital camera
void(vector look, vector offset) camera_orbit =
{
	local vector delta;
	local float dist;
	local entity truck = self.owner;
	local vector avec = truck.avelocity;
	
	local vector view = look * offset.x;
	view.z += offset.z;
	local vector newangles = vectoangles(view);
	view += truck.origin;
	local vector del = truck.origin - self.origin;
	delta = truck.velocity * 0.1;
	delta += view;
	delta -= self.origin;
	dist = vlen(delta);

	if (self.flags & FL_ONGROUND)
		self.flags = self.flags - FL_ONGROUND;

	local vector dang = newangles - self.angles;
	if (dang.y > 180) dang.y += -360;
	else if (dang.y < -180) dang.y += 360;
	self.avelocity = (dang * 10 * 4 + self.avelocity) / 5;

	if (dist > (offset.z - offset.x)) {
		view = look * -20;
		view.z += 40;
		setorigin(self, truck.origin + view);
		self.velocity = truck.velocity;
		return;
	}
	self.velocity = (delta * 10 * 4 + self.velocity) / 5;
}

void() truck_dismount =
{
	if (self.count > time)
		return;
	local entity truck = self.owner;
	remove(self.driver);
	self.driver = world;
	local vector fakeangles = truck.angles;
	local vector view;
	fakeangles.x = -fakeangles.x;
	makevectors(fakeangles);
	self.count = time + 0.5;
		self.impulse = 0;
		setmodel(self, self.model);
		self.movetype = MOVETYPE_WALK;
		view = v_forward * 10 - v_right * 50 + v_up * 40;
		setorigin(self, truck.origin + view);
		self.velocity = truck.velocity;
		self.flags -= FL_VEHICLE + FL_CAMERA + FL_GODMODE;
		self.notrace = 0;
		sprint(self, "Truck dismounted\n");
		truck.driver = world;
		self.owner = world;
		cvar_set("cl_bob", "0.02");
		cvar_set("cl_rollangle", "2");
}

void() truck_jump =
{
	if (self.count > time)
		return;
	self.count = time + 0.5;
	makevectors(self.owner.angles);
	self.owner.velocity.z = self.owner.flyhack.z = self.owner.velocity.z + 135;
	self.owner.velocity = self.owner.flyhack = self.owner.velocity + 80 * v_forward;
self.owner.wheel1.origin.z = self.owner.wheel1.origin.z + 135;
self.owner.wheel1.velocity = self.owner.velocity;
self.owner.wheel2.origin.z = self.owner.wheel2.origin.z + 135;
self.owner.wheel2.velocity = self.owner.velocity;
self.owner.wheel3.origin.z = self.owner.wheel3.origin.z + 135;
self.owner.wheel3.velocity = self.owner.velocity;
self.owner.wheel4.origin.z = self.owner.wheel4.origin.z + 135;
self.owner.wheel4.velocity = self.owner.velocity;
}

void() truck_boost =
{
	if (self.cnt > time)
		return;
	self.cnt = time + 0.5;
	makevectors(self.owner.angles);
	self.owner.velocity = self.owner.velocity + 500 * v_forward;
}

void() truck_fix = //add trigger truck fix to elevators?
{
	local entity truck = self.owner;
	truck.velocity = truck.flyhack = '0 0 0';
	truck.wheel1.velocity = truck.wheel1.flyhack = '0 0 -270';
	truck.wheel2.velocity = truck.wheel2.flyhack = '0 0 -270';
	truck.wheel3.velocity = truck.wheel3.flyhack = '0 0 -270';
	truck.wheel4.velocity = truck.wheel4.flyhack = '0 0 -270';
	//avelocity
	truck.avelocity = '0 0 0';
	//pitch
	truck.angles.x = 0;
	//roll
	truck.angles.z = 0;
	truck.angles.y = self.angles.y;
	//origin.z
	truck.origin.z = truck.origin.z + 18;
	truck.wheel1.origin.z = truck.origin.z + truck.wheel1.view_ofs.z - 3;
	truck.wheel2.origin.z = truck.origin.z + truck.wheel2.view_ofs.z - 3;
	truck.wheel3.origin.z = truck.origin.z + truck.wheel3.view_ofs.z - 3;
	truck.wheel4.origin.z = truck.origin.z + truck.wheel4.view_ofs.z - 3;
	truck.collider1.origin.z = truck.origin.z;
	truck.collider2.origin.z = truck.origin.z;
	self = truck;
	remove(truck.turret);
	spawn_truck_gunner();
	remove(truck.passenger);
	spawn_truck_passenger();
	remove(truck.collider1);
	remove(truck.collider2);
	spawn_truck_bed();
	spawn_truck_front();
	remove(truck.driver.driver);
	self = truck.driver;
	spawn_truck_driver(truck);
}

//other impulse commands
void() truck_ImpulseCommands =
{
	if (self.impulse == 1)
		truck_dismount();
	if (self.impulse == 2)
		truck_jump();
	if (self.impulse == 3)
		truck_boost();
	if (self.impulse == 4)
		truck_fix();

	self.impulse = 0;
}

vector () truck_pilot =
{
	local entity truck = self;
	self = other;
	if (self.classname != "player") {
		dprint("pilot not player");
		return '0 0 0';
	}

if !(self.driver.health) {
	self.modelindex = 0;
	//self.weaponmodel = string_null;
	self.movetype = MOVETYPE_FLY;
	self.owner = truck;
	cvar_set("cl_bob", "0");
	cvar_set("cl_rollangle", "0");
	spawn_truck_driver(truck);
	self.flags += FL_CAMERA + FL_GODMODE;
	self.notrace = 1;
	sprint(self, "\nPress 1 to Dismount\nPress 2 to Jump\nPress 3 to Boost\nPress 4 to Reset\n");
	}
	self.weaponmodel = string_null;
	makevectors(self.v_angle);
	local vector look = v_forward;
	local vector offset = '-100 0 30';
	camera_orbit(look, offset);
	truck_ImpulseCommands();
	self = truck;
	return (look);
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
	if (truck.turret){
		if (!alive(truck.turret)) {
			remove(truck.turret);
			spawn_truck_gunner();}
		self = truck.turret;
		cpywalk(0);
		}
	if (truck.passenger) {
		if (!alive(truck.passenger)) {
			remove(truck.passenger);
			spawn_truck_passenger();}
		self = truck.passenger;
		cpywalk(0); }
	if (truck.collider1) {
		self = truck.collider1;
		cpywalk(0);}
	if (truck.collider2) {
		self = truck.collider2;
		cpywalk(0);}
	if (truck.driver.driver) {
		if (!alive(other.driver)) {
			remove(other.driver);
			spawn_truck_driver(truck);}
		self = other.driver;
		cpywalk(0);
	}
};

void() truck_touch =
{
	if (other.owner == self) return;
	if (other.flags & FL_MONSTER)
		T_Damage(other, self, self, 100);
	
	if (!CheckValidTouch()) return;

	if (!(other.flags & FL_CLIENT))
		return;

	if (self.classname == "truck_collider")
		self = self.owner;

	if (self.driver == other) return;
	if (self.count < time) {
		sprint(other, "Press 1 to drive Truck\n");
		}
	self.count = time + 0.02;
	if (other.impulse == 1) {
		other.impulse = 0;
		self.driver = other;
		other.flags = other.flags + FL_VEHICLE;
		self.flags = self.flags + FL_CLIENT;
		}
}

/*===================================================
Truck Gunner Stuff
===================================================*/

void() W_FireShotgun1 =
{
	local vector dir;

sound(self, CHAN_WEAPON, "weapons/guncock.wav", 1, ATTN_NORM);

self.punchangle_x = -2;
local vector v = self.angles;
v_x *= -1;
makevectors(v);

self.currentammo = self.ammo_shells = self.ammo_shells - 1;
dir = v_forward;

ClearMultiDamage();
FireBullets(6, dir, '0.04 0.04 0');
self.attack_finished = time + 0.5;

ApplyMultiDamage();
}

void() W_FireSuperShotgun1 =
{
	local vector v, dir;
if (self.currentammo == 1)
{
	if (self.items & IT_SHOTGUN)
		W_FireShotgun1();
	return;
}

sound(self ,CHAN_WEAPON, "weapons/shotgn2.wav", 1, ATTN_NORM);

self.punchangle_x = -4;
v = self.angles;
v_x *= -1;
makevectors(v);

self.currentammo = self.ammo_shells = self.ammo_shells - 2;
dir = v_forward;

ClearMultiDamage();

FireBullets(14, dir, '0.14 0.08 0');
self.attack_finished = time + 0.7;

ApplyMultiDamage();
}

void()	gunner_shot1 = [$shotatt1, gunner_shot2] {self.weaponframe = 1;
self.effects = self.effects | EF_MUZZLEFLASH; }
void()	gunner_shot2 = [$shotatt2, gunner_shot3] {self.weaponframe = 2; }
void()	gunner_shot3 = [$shotatt3, gunner_shot4] {self.weaponframe = 3; }
void()	gunner_shot4 = [$shotatt4, gunner_shot5] {self.weaponframe = 4; }
void()	gunner_shot5 = [$shotatt5, gunner_shot6] {self.weaponframe = 5; }
void()	gunner_shot6 = [$shotatt6, gunner_turret_atk1] {self.weaponframe = 6; }

void() W_FireNailgun1 =
{
	vector offset, v, org;

if (!alive(self.enemy) || (enemy_range > 2)) {
self.think = gunner_turret_atk1;
dprint("nailgun1 e out of range\n");
return;}

self.angles = vectoangles(self.enemy.origin - self.origin);
v = self.angles;
v_x *= -1;	// pitch comes back inverted from vectoangles :|
makevectors(v);

sound(self, CHAN_WEAPON, "weapons/rocket1i.wav", 1, ATTN_NORM);
self.currentammo = self.ammo_nails = self.ammo_nails - 1;
offset = VEC_ORIGIN;
if (mod(self.cnt, 2)) offset_x = -2.5;
else offset_x = 2.5;

org = W_SpikeOrigin(offset);
launch_nail(org, v_forward * 1996);
self.attack_finished += 0.09;
}

void()	gunner_nail1 = [$nailatt1, gunner_nail2] { W_FireNailgun1();
self.effects = self.effects | EF_MUZZLEFLASH; }
void()	gunner_nail2 = [$nailatt2, gunner_nail1] {W_FireNailgun1(); 
self.effects = self.effects | EF_MUZZLEFLASH; }

void() gunner_light1 = [$light1, gunner_light2]
{
	self.effects = self.effects | EF_MUZZLEFLASH;
	self.weaponframe = self.weaponframe + 1;
	if (self.weaponframe == 5)
		self.weaponframe = 1;

	W_FireLightning();
	self.attack_finished = time + 0.2;
}
void() gunner_light2 = [$light2, gunner_light1]
{
	self.effects = self.effects | EF_MUZZLEFLASH;
	self.weaponframe = self.weaponframe + 1;
	if (self.weaponframe == 5) {
		self.weaponframe = 1;
		self.think = gunner_check_atk;
		}

	W_FireLightning();
	self.attack_finished = time + 0.2;
}

void() gunner_rocket1 = [$rockatt1, gunner_rocket2] {self.weaponframe = 1;
self.effects = self.effects | EF_MUZZLEFLASH; }
void() gunner_rocket2 = [$rockatt2, gunner_rocket3] {self.weaponframe = 2; }
void() gunner_rocket3 = [$rockatt3, gunner_rocket4] {self.weaponframe = 3; }
void() gunner_rocket4 = [$rockatt4, gunner_rocket5] {self.weaponframe = 4; }
void() gunner_rocket5 = [$rockatt5, gunner_rocket6] {self.weaponframe = 5; }
void() gunner_rocket6 = [$rockatt6, gunner_turret_atk1] {self.weaponframe = 6; }

void() gunner_find_enemy =
{
	local entity m;
	if (alive(self.enemy) && (range(self.enemy) < 3) && visible(self.enemy)) {
		dprint("return from gfe 1\n");
		return;}

	m = nextent(world);
	while (self.enemy == world) {
		if (self.classname != "truck_gunner") { dprint(self.classname); dprint("\n"); }
		if ((m.flags & FL_MONSTER)
		&& (m != self.owner)
		&& alive(m)
		&& (visible(m))
		&& (range(m) < 3)) {
			self.enemy = m;
			dprint("new gunner enemy\n");
			}
		m = nextent(m);
		if (m == world)
			return;
		}
}

void() gunner_choose_yaw =
{
	local entity truck = self.owner;
	enemy_vis = visible(self.enemy);
	enemy_range = range(self.enemy);

	if (alive(self.enemy) && enemy_vis && (enemy_range < 4)) {
		//self.ideal_yaw = enemy_yaw();
		self.ideal_yaw = vectoyaw(self.enemy.origin - self.origin);
	} else {
	local entity pilot = truck.driver;
	self.ideal_yaw = pilot.v_angle.y;
	self.enemy = world;
	gunner_find_enemy();
	self.think = gunner_turret_atk1;
	}
	if (self.classname != "truck_gunner") { dprint(self.classname); dprint("\n"); }
	self.v_angle_y = self.ideal_yaw - truck.angles_y;
	ChangeYaw();
}

void() gunner_check_atk =
{
	local entity pilot = self.owner.driver;
	//dprint("gunner check atk\n");
	gunner_choose_yaw();
	if (!alive(self.enemy)) {
	self.enemy = world;
	dprint("gca e not alive\n");
	return;}
		
	if (enemy_range > 2) {
	//|| !(enemy_vis)) already checked in choose_yaw()
		dprint("gca e out of range\n"); //don't actually engage too far (because glitches)
		return;}
	if (self.classname != "truck_gunner") {dprint(self.classname); dprint("\n");}
	self.angles = vectoangles(self.enemy.origin - self.origin);

	//dprint("gca angles set\n"); np
	if (pilot.weapon == IT_SHOTGUN)
	{
		//dprint("gunner shot called\n");
		gunner_shot1();
		W_FireShotgun1();
	} else if (pilot.weapon == IT_SUPER_SHOTGUN)
	{
		gunner_shot1();
		W_FireSuperShotgun1();
	} else if (pilot.weapon == IT_NAILGUN || pilot.weapon == IT_SUPER_NAILGUN)
	{
		self.ammo_nails = 3;
		gunner_nail1();
		W_FireSpikes();
	} else if (pilot.weapon == IT_GRENADE_LAUNCHER)
	{
		player_rocket1();
		W_FireGrenade();
	} else if (pilot.weapon == IT_ROCKET_LAUNCHER)
	{
		player_rocket1();
		W_FireRocket();
	}

	else if (pilot.weapon == IT_LIGHTNING)
	{
		gunner_light1();
		self.attack_finished = time + 0.1;
		sound(self, CHAN_AUTO, "weapons/lstart.wav", 1, ATTN_NORM);
	}
}

void() gunner_turret_atk1 = [0, gunner_turret_atk2] {gunner_choose_yaw();}
void() gunner_turret_atk2 = [0, gunner_turret_atk3] {gunner_choose_yaw();}
void() gunner_turret_atk3 = [self.frame, gunner_turret_atk1] {gunner_check_atk();}

//===================================================
//SPAWNING
//===================================================

//demo gunner
void() spawn_truck_gunner =
{
	local entity truck = self;
	local entity gunner = spawn();
	self = gunner;

	truck.turret = gunner;
	gunner.owner = truck;
	self.classname = "truck_gunner";
	setmodel(self, "progs/player.mdl");
	setsize(self, '-10 -10 0', '10 10 30');
	self.view_ofs = '-35 0 25';
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;
	self.health = 1;
	setorigin(self, truck.origin + self.view_ofs); //fix next truck think
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
	setsize(self, '-10 -10 0', '10 10 30');
	self.view_ofs = '5 7 20';
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;
	self.health = 1;
	setorigin(self, truck.origin + self.view_ofs);
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
	self.view_ofs = '32 12 7';
	} else if (i == 1) {
	truck.wheel2 = self;
	self.view_ofs = '32 -12 7';
	} else if (i == 2) {
	truck.wheel3 = self;
	self.view_ofs = '-32 12 7';
	} else if (i == 3) {
	truck.wheel4 = self;
	self.view_ofs = '-32 -12 7';
	} else dprint("too many wheels spawned!\n");
	setorigin(self, truck.origin + self.view_ofs);
	self = truck;
}

/*@PointCLass base(Monster) size(-32 - 32 18, 32 32 64) model(
	{ {
		mdl_body -> {"path" : mdl_body, "skin" : skin}, {"path": "progs/mini_truck.mdl" , "skin" : skin}
	} }
) = monster_truck : "mini truck"
[
]
*/

void() spawn_truck_bed =
{
	local entity truck = self;
	local entity bed = spawn();
	self = bed;
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;
	self.flags = FL_VEHICLE;
	setsize(self, '-20 -20 20', '20 20 52');
	self.view_ofs = '-27 0 0';
	setorigin(self, truck.origin + self.view_ofs);
	self.touch = truck.touch;
	truck.collider2 = self;
	self.owner = truck;
	self.classname = "truck_collider";
	self = truck;
}

void() spawn_truck_front =
{
	local entity truck = self;
	local entity front = spawn();
	self = front;
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;
	self.flags = FL_VEHICLE;
	setsize(self, '-20 -20 20', '20 20 52');
	self.view_ofs = '16 0 0';
	setorigin(self, truck.origin + self.view_ofs);
	self.touch = truck.touch;
	truck.collider1 = self;
	self.owner = truck;
	self.classname = "truck_collider";
	self = truck;
}

void() spawn_monster_truck =
{
	//body with wheels model
	self.solid = SOLID_TRIGGER;
	self.movetype = MOVETYPE_FLY;
	self.flags = FL_VEHICLE + FL_MONSTER;
	setmodel(self, "progs/mini_truck.mdl");
	setsize(self, '-8 -8 28', '8 8 36');
	self.classname = "monster_truck";
	self.angles.y = self.angles.y;

	//wheels -- not the visible model
	local float i = 0;
	while (i < 4)
	{
		spawn_truck_wheel(i);
		i++;
	}
	self.touch = truck_touch;
	self.think = truck_drive;
	self.nextthink = time + 0.1;
	spawn_truck_bed();
	spawn_truck_front();
	//gunner
	//if (self.spawnflags & I_AM_TURRET) {
		spawn_truck_gunner();
		spawn_truck_passenger();
		//}
};

void() monster_truck =
{
	precache_model("progs/mini_truck.mdl");
	spawn_monster_truck();
}
