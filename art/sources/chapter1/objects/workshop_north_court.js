// Native LibreSprite assembly, 1:1 project pixels; north-entry courtyard.
app.open('game/assets/chapter1/objects/tool_bench.png');
const donor=sprite.layer(0).cel(0).image; const tool=[];
for(let y=0;y<80;y++){let row=[];for(let x=0;x<96;x++)row.push(donor.getPixel(x,y));tool.push(row);}
app.open('art/sources/chapter1/objects/farmhouse_original.png');
const im=sprite.layer(0).cel(0).image;im.clear(0);
function ink(h){return app.pixelColor.rgba(parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16),255);}
const stone=ink('a49b78'),seam=ink('81775b'),light=ink('c1b38b'),wood=ink('89653d'),edge=ink('bf965b'),dark=ink('51442d');
function rect(x,y,w,h,c){for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)im.putPixel(xx,yy,c);}
rect(24,53,144,96,stone);
for(let y=53;y<149;y+=16){rect(24,y,144,1,seam);for(let x=24+((y-53)/16%2)*16;x<168;x+=32)rect(x,y,1,16,seam);}
// Wide northern threshold agrees with the existing north-side interaction.
rect(80,37,32,16,light);rect(80,50,32,2,seam);
for(const x of [24,162]){rect(x,37,6,112,dark);rect(x+1,38,4,110,wood);rect(x,37,6,3,edge);}
// Northern rails leave the central entrance visibly open.
for(const part of [[30,50],[112,50]]){rect(part[0],42,part[1],5,wood);rect(part[0],42,part[1],1,edge);}
rect(24,141,144,8,wood);rect(24,141,144,2,edge);
for(let y=0;y<80;y++)for(let x=0;x<96;x++){const p=tool[y][x];if(app.pixelColor.rgbaA(p)>0)im.putPixel(x+48,y+63,p);}
// Two modest timber stacks, readable workshop materials rather than noise.
for(const x of [32,149])for(let y=95;y<136;y+=10){rect(x,y,11,7,dark);rect(x+1,y+1,9,4,wood);rect(x+1,y+1,9,1,edge);}
// Masonry footings and capped timber posts make the north-open workshop yard legible.
for(const x of [22,160])for(const y of [37,87,137]){rect(x,y+4,10,8,seam);rect(x,y+3,10,2,light);rect(x+2,y-2,6,8,dark);rect(x+3,y-1,4,6,wood);rect(x+2,y-2,6,2,edge);}
for(const x of [26,164])for(let y=58;y<132;y+=12)rect(x,y,1,6,edge);
for(let x=35;x<158;x+=20){rect(x,142,11,1,edge);rect(x+4,146,9,1,dark);}
sprite.saveAs('art/sources/chapter1/objects/workshop_north_court.aseprite',false);
sprite.saveAs('game/assets/chapter1/objects/workshop_north_court.png',true);
console.log('WORKSHOP_NORTH_COURT_NATIVE_DONE');
