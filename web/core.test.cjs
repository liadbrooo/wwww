const assert=require("node:assert/strict"),core=require("./core.js");globalThis.crypto??=require("node:crypto").webcrypto;
const a={id:"a",kind:"video",lane:0,start:0,length:2},b={id:"b",kind:"video",lane:0,start:2,length:2};const p={clips:[a,b],videoTrackCount:4,audioTrackCount:3};assert.deepEqual(core.lanes(p),[3,2,1,0,-1,-2,-3]);assert(core.moveGroup(p,new Set(["a","b"]),1,1));assert.equal(b.start,3);p.lockedTracks=[1];assert(!core.moveGroup(p,new Set(["a"]),1,0));core.removeGroup(p,new Set(["a"]),false);assert.equal(p.clips.length,2);p.lockedTracks=[];core.removeGroup(p,new Set(["a"]),true);assert.equal(b.start,1);
const clip={id:crypto.randomUUID(),kind:"title",name:"Title",start:0,length:2,in:0,speed:1,lane:2,volume:1,opacity:1,scale:1,x:.4,y:-.6,rotation:30,brightness:1.2,contrast:1,saturation:1,blur:0,grayscale:0,sepia:0,fadeIn:0,fadeOut:0,fill:false,mask:"none",maskSize:.8,text:"Title",font:72,keys:[]};
const native=core.toNative({name:"Test",ratio:"16:9",fps:29.97,clips:[clip],markers:[]},[]);const result=core.fromNative(native).project;assert.equal(result.fps,29.97);assert.equal(result.clips[0].rotation,30);assert.equal(result.clips[0].x,.4);assert(Math.abs(result.clips[0].brightness-1.2)<1e-9);native.clips[0].effect="comic";assert.throws(()=>core.fromNative(native));console.log("Core tests passed");

const source=new Map([["source",{duration:30}]]),mk=(id,start,sourceIn)=>({id,media:"source",kind:"video",lane:0,start,in:sourceIn,length:4,speed:1,fadeIn:0,fadeOut:0,keys:[]});const pro={fps:30,clips:[mk("l",0,2),mk("c",4,3),mk("r",8,4)]};const pose=(x,t)=>x;
assert(core.professionalEdit(pro,"c","slip",30,source,pose));assert.equal(pro.clips[1].in,4);
assert(core.professionalEdit(pro,"c","roll",30,source,pose));assert.equal(pro.clips[2].start,9);
assert(core.professionalEdit(pro,"c","slide",-30,source,pose));assert.equal(pro.clips[1].start,3);
assert(core.professionalEdit(pro,"c","ripple",-30,source,pose));assert.equal(pro.clips[2].start+pro.clips[2].length,11);
const old=JSON.stringify(pro);assert(!core.professionalEdit(pro,"c","slip",3000,source,pose));assert.equal(JSON.stringify(pro),old);
assert(core.dissolveInto(pro,"c",.5));assert.equal(pro.clips[1].fadeIn,.5);assert.equal(pro.clips[2].start+pro.clips[2].length,10.5);console.log("Professional editing tests passed");

const pref=require("./preferences.js");assert.equal(pref.normalize({defaultVideoTracks:8,monitorVolume:50,previewFPS:30}).defaultVideoTracks,8);assert.equal(pref.normalize({defaultVideoTracks:100}).defaultVideoTracks,3);
