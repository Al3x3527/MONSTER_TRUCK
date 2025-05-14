.float travel_time;

// This is a modified SUB_CalcMove routine.
void(vector tdest, float tspeed, entity cam) Kino_CalcMove = //(SUB_DHM_CalcMove)
{
local   vector  vdestdelta;
local   float   len, traveltime;

    self.finaldest = tdest;
    self.think = DHM_CalcMoveDone;

    if (tdest == cam.origin)
    {
        cam.velocity = cam.mangle = '0 0 0';
        self.nextthink = time + 0.01;
        return;
    }

// set destdelta to the vector needed to move
    vdestdelta = tdest - cam.origin;

// calculate length of vector
    len = vlen (vdestdelta);

//ignore speed --ALEX
	if (self.travel_time > 0) traveltime = self.travel_time; 
	else if (self.travel_time == -1) traveltime = 0;
	else {
	dprint("travel_time not set\n");
///

// divide by speed to get time to reach dest
    traveltime = len / tspeed;
	}
	dprint_float(traveltime); dprint("\n");
    if (traveltime < 0.1)
    {
        cam.velocity = cam.mangle = '0 0 0';
        self.nextthink = time + 0.01;
        return;
    }

// set nextthink to trigger a think when dest is reached
    self.nextthink = time + traveltime;

// scale the destdelta vector by the time spent traveling to get velocity
    cam.velocity = cam.mangle = vdestdelta * (1/traveltime);

//avelocity --ALEX
	cam.avelocity = (cam.oldorigin - cam.angles) * (1 / traveltime); //fake

///
};

//set self to cam, v_angle, view_ofs, owner to following before calling
void() Kino_cpywalk = 
{
	local vector delta, deltay, deltax1, deltax2, deltaz;
	local float dist;
	local entity master = self.owner;
	
	local vector avec = master.avelocity;
	local vector fakeangles = master.angles;
	fakeangles.x = -fakeangles.x;
	makevectors(fakeangles);

	//from origin
	local vector del = master.origin - self.origin;
	//from angular
	deltay = avec.y * 0.1 * (6.28 / 360) * ((del * v_forward) * v_right + (del * v_right) * v_forward);
	deltax1 = -avec.x * 0.628 / 360 * (del * v_forward) * v_up;
	deltax2 = -avec.x * 0.628 / 360 * (del * v_up) * v_forward;
	deltaz = -avec.z * 0.628 / 360 * ((del * v_right) * v_up + (del * v_up) * v_right);
	//from velocity
	delta = deltay + deltax1 + deltax2 + deltaz + master.velocity * 0.1;
	//actual delta
	local vector view = self.view_ofs + master.view_ofs;
	view = view.x * v_forward + view.y * v_right + view.z * v_up + master.origin;
	delta = delta + view - self.origin;
	dist = vlen(delta);

	local vector dang;
	dang = master.angles + self.v_angle - self.angles;
	if (dang.y > 180) dang.y = -360 + dang.y;
	else if (dang.y < -180) dang.y = 360 + dang.y;
	self.avelocity = dang * 10;

	if (dist > 100) {
		//dprint("cpywalk setorigin\n");
		setorigin(self, view);
		self.velocity = master.velocity;
		return;
	}

	self.velocity = delta * 10;
	//dprint(vtos(delta * 10)); dprint(vtos(self.velocity)); dprint("velocity\n");
};

void() SUB_move_camera =
{
local   entity  cpt, fpt;
local   vector  looky;

	if (!cutscene)      // Old check:  if (self.enemy.classname != "camera")
		{
remove(self); return;
}

cpt = find(world, targetname, self.target);
if (!cpt.target)     //if this is the end of the line, stop camera
{
	self.think = SUB_Null;
	self.enemy.velocity = '0 0 0';
	self.enemy.mangle = '0 0 0';     //mangle == velocity in cut-scene
	DHM_CalcMoveDone();
	self.cnt = -1;    // remove control entity in DHM_CalcMoveDone
	//return;
}
if (cpt.focal_point)    //is there a new focal point?
{
	fpt = find(world, targetname, cpt.focal_point);
	if (!fpt)
		objerror("Couldn't find new focal point!");

	self.enemy.movedir = fpt.origin;
	looky_x = self.enemy.movedir_x - self.enemy.origin_x;
	looky_y = self.enemy.movedir_y - self.enemy.origin_y;
	looky_z = self.enemy.origin_z - self.enemy.movedir_z;
	self.enemy.oldorigin = vectoangles(looky);
	self.enemy.angles = self.enemy.oldorigin;    //oldorigin == angles in CS
}
// Check for auto-focus or still camera angle
	if (cpt.delay)
		self.enemy.delay = cpt.delay;
	else
		self.enemy.delay = 0;

	self.target = cpt.target;
	self.wait = cpt.wait;
	if (cpt.speed)
		self.speed = cpt.speed;

	//travel_time --ALEX
	if (cpt.travel_time)
		self.travel_time = cpt.travel_time;
	else self.travel_time = 0;
	Kino_CalcMove(cpt.origin, self.speed, self.enemy);
	///
};

//TESTING

void() FakeAvelocity =
{
	self.enemy.v_angle = self.enemy.angles += self.enemy.avelocity * 0.04;
	self.enemy.fixangle = 1;
	dprint(self.enemy.classname); dprint("\n");
	self.nextthink = time + 0.04;
}

void() avelocity_test =
{
	/* This doesn't work
	//if (!CheckValidTouch()) return;
	other = activator;
	other.movetype = MOVETYPE_NOCLIP;
	other.avelocity = '0 50 0';
	setorigin(other, other.origin + '0 0 30');
	other.modelindex = 0;
	other.fixangle = 1;
	//other.view_ofs = '0 0 0';
	other.weaponmodel = "";
	other.velocity = '10 0 10';
	dprint(other.classname);
	//intermission_running = 1;
	*/

	self.enemy = activator;
	activator.movetype = MOVETYPE_NOCLIP;
	activator.avelocity = '50 50 50'; //fake
	setorigin(activator, activator.origin + '0 0 50');
	activator.fixangle = 1;
	activator.weaponmodel = "";
	self.think = FakeAvelocity;
	self.nextthink = time + 0.04;

	dprint("avelocity test\n");
}

void() trigger_avelocity =
{
	self.use = avelocity_test;
}

///