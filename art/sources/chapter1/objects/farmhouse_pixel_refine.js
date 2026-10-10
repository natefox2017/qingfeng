// Native LibreSprite pixel edit. Existing Qingfeng well roof is the material
// donor; all transfers are 1:1 pixels, with hard clipped roof planes.
const root='';
app.open(root+'game/assets/chapter1/objects/well.png');
const donor=sprite.layer(0).cel(0).image;
const tiles=[];
for(let y=5;y<34;y++){let row=[];for(let x=11;x<66;x++)row.push(donor.getPixel(x,y));tiles.push(row);}
app.open(root+'art/sources/chapter1/objects/farmhouse_original.png');
const im=sprite.layer(0).cel(0).image;
const pc=app.pixelColor;
function ink(hex){let s=hex.replace('#','');return pc.rgba(parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16),255);}
const pal={shadow:ink('343c3a'),beam:ink('705334'),wood:ink('947047'),edge:ink('bf9360'),cream:ink('dfc79b'),light:ink('efdcb2'),shade:ink('b89b70'),roofdark:ink('243d49'),roofedge:ink('578392'),glass:ink('80b7bf'),glint:ink('c9e2d7'),green:ink('386345'),leaf:ink('6a974c'),leaflit:ink('a9bc65'),flower:ink('f1e7c6'),petal:ink('deaa8a')};
function px(x,y,c){im.putPixel(x,y,c);}
function rect(x,y,w,h,c){for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)px(xx,yy,c);}
function line(x0,y0,x1,y1,c){let dx=Math.abs(x1-x0),sx=x0<x1?1:-1,dy=-Math.abs(y1-y0),sy=y0<y1?1:-1,e=dx+dy;while(true){px(x0,y0,c);if(x0===x1&&y0===y1)break;let e2=2*e;if(e2>=dy){e+=dy;x0+=sx;}if(e2<=dx){e+=dx;y0+=sy;}}}
function inside(x,y,pts){let c=false;for(let i=0,j=pts.length-1;i<pts.length;j=i++){let a=pts[i],b=pts[j];if((a[1]>y)!=(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])c=!c;}return c;}
function poly(pts,c){for(let y=0;y<152;y++)for(let x=0;x<192;x++)if(inside(x,y,pts))px(x,y,c);}
function roof(pts,ox,oy){for(let y=0;y<110;y++)for(let x=0;x<192;x++)if(inside(x,y,pts))px(x,y,tiles[((y-oy)%29+29)%29][((x-ox)%55+55)%55]);for(let n=0;n<pts.length;n++){let a=pts[n],b=pts[(n+1)%pts.length];line(a[0],a[1],b[0],b[1],pal.roofdark);}}
// Recompose the oversized single triangle as side wings and a central gable.
rect(0,0,192,92,0);
poly([[18,82],[174,82],[174,141],[18,141]],pal.cream);
rect(18,91,156,6,pal.shade);
roof([[14,54],[79,54],[79,96],[7,96]],11,54);
roof([[112,54],[178,54],[185,96],[112,96]],11,54);
// Two intentionally drawn native planes, no resize/filter/noise.
roof([[94,10],[96,50],[47,101],[28,76]],28,13);
roof([[96,10],[157,75],[145,103],[96,50]],101,13);
poly([[96,54],[48,103],[144,103]],pal.light);
poly([[96,61],[61,98],[132,98]],pal.cream);
line(94,12,95,48,pal.roofedge);line(95,49,46,101,pal.wood);line(96,50,145,103,pal.wood);
line(95,52,50,99,pal.edge);line(98,53,143,101,pal.edge);
rect(10,97,37,4,pal.beam);rect(146,97,37,4,pal.beam);
rect(10,97,37,1,pal.edge);rect(146,97,37,1,pal.edge);
// Attic sash, shaped eaves and timbers give a readable front silhouette.
rect(87,78,19,22,pal.beam);rect(89,80,15,17,pal.edge);rect(90,81,13,15,pal.glass);
rect(95,81,2,16,pal.light);rect(90,88,13,2,pal.light);line(90,82,94,82,pal.glint);
rect(18,101,5,39,pal.beam);rect(169,101,5,39,pal.beam);rect(24,102,144,3,pal.edge);
rect(18,139,156,4,pal.beam);rect(23,136,146,3,pal.shade);
// Preserve the exact existing door opening/foot anchor; add framed windows.
function windowAt(x){rect(x,108,27,26,pal.beam);rect(x+2,109,23,21,pal.edge);rect(x+4,111,19,17,pal.glass);rect(x+12,111,2,17,pal.light);rect(x+4,118,19,2,pal.light);rect(x+4,111,6,2,pal.glint);rect(x-1,131,29,3,pal.edge);}
windowAt(35);windowAt(131);
rect(77,106,38,4,pal.beam);rect(78,106,36,1,pal.edge);rect(78,110,4,30,pal.edge);rect(111,110,4,30,pal.beam);
rect(84,111,25,29,pal.wood);rect(85,112,10,27,pal.beam);rect(98,112,10,27,pal.beam);rect(103,124,2,2,pal.edge);
rect(76,141,41,4,pal.shade);rect(74,145,45,3,pal.light);rect(75,148,43,2,pal.shadow);
function planter(x){rect(x,135,31,6,pal.beam);rect(x+1,135,29,2,pal.edge);rect(x+2,138,27,2,pal.wood);for(const o of [[2,-2],[7,-5],[11,-1],[15,-4],[20,-3],[24,-5]]){rect(x+o[0],133+o[1],5,5,pal.green);rect(x+o[0]+1,132+o[1],3,3,pal.leaf);px(x+o[0]+2,131+o[1],pal.leaflit);}for(const o of [[7,127],[17,128],[25,125]]){rect(x+o[0],o[1],3,3,pal.flower);px(x+o[0]+1,o[1]+1,pal.petal);}}
planter(33);planter(130);
// Stone-capped brick chimney is a separate readable high point.
rect(29,32,13,23,pal.beam);rect(30,33,11,20,pal.shade);rect(31,34,9,3,pal.edge);rect(31,42,9,3,pal.edge);rect(31,50,9,3,pal.edge);line(34,37,34,40,pal.beam);line(37,45,37,48,pal.beam);rect(27,29,17,5,pal.shadow);rect(28,29,15,2,pal.light);
sprite.saveAs('art/sources/chapter1/objects/farmhouse_pixel_refine.aseprite',false);
sprite.saveAs('art/sources/chapter1/objects/farmhouse_blue.png',true);
console.log('FARMHOUSE_NATIVE_DETAIL_DONE');
