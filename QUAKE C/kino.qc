.float travel_time;
.float aspeed;

// This is a modified SUB_CalcMove routine.
void(vector tdest, float tspeed, entity cam) Kino_CalcMove =
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
	if (cam.travel_time > 0) traveltime = cam.travel_time; //ignore speed
	else if (cam.travel_time == -1) traveltime = 0;
	else {
// set destdelta to the vector needed to move
    vdestdelta = tdest - cam.origin;

// calculate length of vector
    len = vlen (vdestdelta);

// divide by speed to get time to reach dest
    traveltime = len / tspeed;
	}
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
//avelocity
	cam.avelocity = (cam.oldorigin - cam.angles) * (cam.aspeed / traveltime);
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