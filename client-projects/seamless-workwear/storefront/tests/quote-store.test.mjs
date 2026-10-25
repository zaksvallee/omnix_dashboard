import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {Readable} from 'node:stream';
import {QuoteStore} from '../src/quote-store.mjs';
import {validateQuoteDraft} from '../src/catalogue.mjs';
import {createHandler} from '../server.mjs';
const token='a'.repeat(64),other='b'.repeat(64),staff='staff-fixture-'.repeat(4);
const input=()=>({items:[{id:'golf-shirt',quantity:44,branding:'embroidery',requestedVariants:[{colour:'Navy',size:'M',quantity:12},{colour:'Navy',size:'L',quantity:24},{colour:'White',size:'XL',quantity:8}]}],contact:{name:'Fixture buyer',email:'buyer@example.test'},notes:'Review before ordering',price:0,paymentAvailable:true});
test('matrix sums exact quantities, isolates colour/size cells and never accepts client pricing',()=>{
 const d=validateQuoteDraft(input());assert.equal(d.items[0].quantity,44);assert.equal(d.priced,false);assert.equal(d.paymentAvailable,false);assert.equal(d.price,undefined);
 const mismatch=input();mismatch.items[0].quantity=45;assert.throws(()=>validateQuoteDraft(mismatch));
 for(const qty of [-1,1.5,10001]){const d=input();d.items[0].requestedVariants[0].quantity=qty;assert.throws(()=>validateQuoteDraft(d));}
 const duplicate=input();duplicate.items[0].requestedVariants[1]={colour:' navy ',size:'m',quantity:24};assert.throws(()=>validateQuoteDraft(duplicate));
 const blank=input();blank.items[0].requestedVariants[0].colour='';assert.throws(()=>validateQuoteDraft(blank));
});
test('requests persist through reopen, retry is idempotent, ownership is enforced and tokens are hashed',()=>{
 const dir=mkdtempSync(path.join(tmpdir(),'seamless-quote-')),file=path.join(dir,'quotes.sqlite');let s=new QuoteStore(file);
 try{const q=s.create(input(),token);assert.equal(q.status,'needs_review');assert.equal(q.price,null);assert.equal(s.create(input(),token).id,q.id);assert.equal(s.list().length,1);assert.equal(s.get(q.id,other),null);assert.equal(s.get(q.id,''),null);const changed=input();changed.notes='changed';assert.throws(()=>s.create(changed,token),e=>e.status===409);s.close();s=new QuoteStore(file);assert.equal(s.get(q.id,token).items[0].requestedVariants.length,3);assert.equal(readFileSync(file).includes(Buffer.from(token)),false);assert.equal(JSON.stringify(s.list()).includes('owner_hash'),false);}finally{s.close();rmSync(dir,{recursive:true,force:true});}
});
test('staff review revisions and events are atomic, stale reviews fail and closed requests stay closed',()=>{
 const s=new QuoteStore(':memory:');try{const q=s.create(input(),token);const r=s.review(q.id,{status:'in_review',note:'Check supplier stock',expectedRevision:1});assert.equal(r.revision,2);assert.equal(r.events.length,2);assert.throws(()=>s.review(q.id,{status:'closed',note:'stale',expectedRevision:1}),e=>e.status===409);assert.equal(s.list()[0].events.length,2);assert.equal(s.get(q.id,token).events,undefined);assert.throws(()=>s.review(q.id,{status:'production',note:'not allowed',expectedRevision:2}));s.review(q.id,{status:'closed',note:'Customer withdrew request',expectedRevision:2});assert.throws(()=>s.review(q.id,{status:'in_review',note:'reopen',expectedRevision:3}),e=>e.status===409);}finally{s.close();}
});
async function call(handler,url,{method='GET',body,headers={}}={}){const req=Readable.from(body===undefined?[]:[Buffer.from(JSON.stringify(body))]);Object.assign(req,{url,method,headers:{host:'localhost:4318',origin:'http://localhost:4318','content-type':'application/json',...headers},socket:{remoteAddress:'127.0.0.1'}});const res={status:200,headers:{},setHeader(k,v){this.headers[k]=v;},writeHead(status,h){this.status=status;Object.assign(this.headers,h);},end(b){this.body=b;}};await handler(req,res);return res;}
test('HTTP flow saves a private request, rejects foreign/unauthorised access and permits scoped staff review',async()=>{
 const store=new QuoteStore(':memory:'),handler=createHandler({store,staffToken:staff});try{
 assert.equal((await call(handler,'/api/staff/quotes')).status,401);
 assert.equal((await call(createHandler({store,staffToken:''}),'/api/staff/quotes')).status,503);
 assert.equal((await call(handler,'/api/quotes',{method:'POST',body:input(),headers:{origin:'https://evil.test','x-request-token':token}})).status,403);
 const saved=await call(handler,'/api/quotes',{method:'POST',body:input(),headers:{'x-request-token':token}});assert.equal(saved.status,201);const q=JSON.parse(saved.body);
 assert.equal((await call(handler,'/api/quotes/'+q.id,{headers:{authorization:'Bearer '+other}})).status,404);
 assert.equal((await call(handler,'/api/quotes/'+q.id,{headers:{authorization:'Bearer '+token}})).status,200);
 const queue=await call(handler,'/api/staff/quotes',{headers:{authorization:'Bearer '+staff}});assert.equal(JSON.parse(queue.body).quotes.length,1);
 assert.equal((await call(handler,'/api/staff/quotes/'+q.id,{method:'POST',body:{status:'in_review',note:'Staff checking',expectedRevision:1},headers:{authorization:'Bearer '+staff}})).status,200);
 assert.equal((await call(handler,'/runtime/seamless.sqlite')).status,404);
 }finally{store.close();}
});
test('public creation is bounded per address',async()=>{const store=new QuoteStore(':memory:'),handler=createHandler({store});try{for(let n=0;n<10;n++)assert.equal((await call(handler,'/api/quotes',{method:'POST',body:input(),headers:{'x-request-token':token}})).status,201);assert.equal((await call(handler,'/api/quotes',{method:'POST',body:input(),headers:{'x-request-token':token}})).status,429);}finally{store.close();}});
