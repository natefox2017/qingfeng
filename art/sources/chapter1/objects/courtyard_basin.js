// Native LibreSprite 1:1 reuse of the approved-project well's stone ring/water.
// The source well is unchanged. Remove roof and posts; retain a low open basin.
app.open('game/assets/chapter1/objects/well.png');
const im=sprite.layer(0).cel(0).image;
for(let y=0;y<51;y++)for(let x=0;x<80;x++)im.putPixel(x,y,0);
const pc=app.pixelColor;
function ink(h){return pc.rgba(parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16),255);}
const edge=ink('b8bb8e'),shade=ink('8d906d'),water=ink('459bb0'),glint=ink('91d1d1');
// Replace the former wooden supports at the rear rim using stone tones.
for(const x0 of [14,60])for(let y=51;y<68;y++)for(let x=x0;x<x0+6;x++)im.putPixel(x,y,y<55?edge:shade);
// Small water glints, no tall sculpture or roof, no scaling.
for(const p of [[33,70],[34,70],[35,70],[43,73],[44,73],[45,73],[37,75],[38,75]])im.putPixel(p[0],p[1],glint);
im.putPixel(40,69,water);
sprite.saveAs('art/sources/chapter1/objects/courtyard_basin.aseprite',false);
sprite.saveAs('game/assets/chapter1/objects/courtyard_basin.png',true);
console.log('COURTYARD_BASIN_NATIVE_DONE');
