// Isolated local browser process running the same repository-owned acceptance scripts.
import {chromium} from 'playwright';
const channel=process.env.READING_NOTES_BROWSER_CHANNEL ?? 'chrome';
const browser=await chromium.launch({channel,headless:true});
try {
 const context=await browser.newContext({viewport:null});
 const page=await context.newPage(), session=await context.newCDPSession(page), events=[];
 await session.send('Page.enable');
 for(const method of ['Network.requestWillBeSent','Network.responseReceived','Network.loadingFailed','Runtime.exceptionThrown'])
   session.on(method,params=>events.push({method,params}));
 const wrapped=new Proxy(page,{get(target,key){
   if(key==='cdp')return (method,params={})=>session.send(method,params);
   if(key==='events')return async()=>events.splice(0);
   if(key==='waitForFunction')return async(fn,arg,options={})=>{
     const deadline=Date.now()+(options.timeout??10000);
     while(Date.now()<deadline){const value=await page.evaluate(fn,arg);if(value)return value;await new Promise(resolve=>setTimeout(resolve,50));}
     throw new Error('waitForFunction timed out');
   };
   if(key==='click')return (selector,{label,...options}={})=>page.click(selector,options);
   if(key==='mouse')return {
     click:(x,y,{label,...options}={})=>page.mouse.click(x,y,options),
     move:(x,y,{label,...options}={})=>page.mouse.move(x,y,options),
     wheel:(x,y)=>page.mouse.wheel(x,y),
   };
   const value=Reflect.get(target,key);return typeof value==='function'?value.bind(target):value;
 }});
 const taskSpace=async requested=>{
   if(typeof requested==='number'&&requested!==1)throw new Error(`task space not found: ${requested}`);
   return {spaceId:1,page:()=>wrapped};
 };
 let script='';for await(const chunk of process.stdin)script+=chunk;
 console.log(JSON.stringify({driver:'playwright',channel,browser_version:browser.version()}));
 const AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;
 await new AsyncFunction('taskSpace',script)(taskSpace);
} finally { await browser.close(); }
