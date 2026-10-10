// Native LibreSprite pencil rows, deliberately stepped hard edges.
// Existing bush is only the 64px working canvas; no image resampling/noise.
app.open('game/assets/chapter1/objects/bush.png');
const im=sprite.layer(0).cel(0).image;
im.clear(0);
const outer=app.pixelColor.rgba(126,151,50,255);
const inner=app.pixelColor.rgba(107,131,43,255);
for(const row of [[56,24,42],[57,17,48],[58,12,52],[59,9,55],[60,9,55],[61,12,52],[62,17,48],[63,25,40]]){
 for(let x=row[1];x<=row[2];x++) im.putPixel(x,row[0],outer);
}
for(const row of [[58,23,43],[59,17,48],[60,16,48],[61,21,43]]){
 for(let x=row[1];x<=row[2];x++) im.putPixel(x,row[0],inner);
}
sprite.saveAs('art/sources/chapter1/objects/shrub_ground_shadow.aseprite',false);
sprite.saveAs('art/sources/chapter1/objects/shrub_ground_shadow.png',true);
console.log('SHRUB_GROUND_SHADOW_NATIVE_DONE');
