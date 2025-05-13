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
