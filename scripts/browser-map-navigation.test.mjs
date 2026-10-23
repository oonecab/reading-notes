import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { mapLandingMatches, waitMapExposure, waitLanding } from './browser-map-navigation.mjs';

test('a chapter map URL alone cannot prove a visible chapter destination', () => {
  const expected = {url:'https://example.test/book.html#chapter-8',target_title:'8 · 模块'};
  const state = {url:expected.url,title:expected.target_title,ready:true,visible:true,top:130,bottom:180,blocker_bottom:110,viewport:950,viewport_width:390,width:375};
  assert(mapLandingMatches(state,expected));
  for (const mutation of [{top:1200,bottom:1250},{top:80},{title:'章节依赖图'},{visible:false},{ready:false},{width:700},{width:0},{url:'https://example.test/book.html#chapter-7'}]) {
    assert.equal(mapLandingMatches({...state,...mutation},expected),false,JSON.stringify(mutation));
  }
});


test('map wheel visibility waits for the final compositor position', async () => {
  const samples = [
    {scrollLeft:77.5,node_visible:false},
    {scrollLeft:155.5,node_visible:true},
    {scrollLeft:155.5,node_visible:true},
    {scrollLeft:155.5,node_visible:true},
  ];
  let reads=0;
  const page={evaluate:async()=>samples[Math.min(reads++,samples.length-1)]};
  const result=await waitMapExposure(page,11,{timeout:1000,interval:1});
  assert.equal(result.scrollLeft,155.5);
  assert.equal(reads,4,'intermediate clipped geometry must not end the check');
});

test('map wheel visibility still rejects a persistently clipped node', async () => {
  const page={evaluate:async()=>({scrollLeft:77.5,node_visible:false})};
  await assert.rejects(waitMapExposure(page,11,{timeout:20,interval:1}),/did not become fully visible/);
});


test('map landing waits through an empty navigation document', async () => {
  const expected={kind:'chapter',url:'https://example.test/chapter12.html',target_title:'第十二章'};
  const landing={url:expected.url,title:expected.target_title,ready:true,visible:true,top:130,bottom:160,blocker_bottom:110,viewport:950,viewport_width:390,width:375};
  let reads=0;
  const page={evaluate:async(fn,arg)=>{
    if(reads++===0)return vm.runInNewContext('('+fn.toString()+')(expected)',{
      expected:arg,location:{href:arg.url},innerHeight:950,innerWidth:390,
      document:{readyState:'loading',documentElement:null,querySelector:()=>null,getElementById:()=>null}
    });
    return landing;
  }};
  assert.deepEqual(await waitLanding(page,expected,{timeout:1000,interval:1}),landing);
  assert.equal(reads,4,'three stable complete readings must follow the empty document');
});

test('an empty completed document cannot satisfy a map destination', async () => {
  const expected={kind:'chapter',url:'https://example.test/empty.html',target_title:'第十二章'};
  const page={evaluate:async(fn,arg)=>vm.runInNewContext('('+fn.toString()+')(expected)',{
    expected:arg,location:{href:arg.url},innerHeight:950,innerWidth:390,
    document:{readyState:'complete',documentElement:null,querySelector:()=>null,getElementById:()=>null}
  })};
  await assert.rejects(waitLanding(page,expected,{timeout:20,interval:1}),/Chapter map did not reach its visible target/);
});
