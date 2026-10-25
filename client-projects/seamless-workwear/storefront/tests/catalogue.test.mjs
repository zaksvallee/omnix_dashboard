import {test} from 'node:test';import assert from 'node:assert/strict';import {catalogue,validateQuoteDraft} from '../src/catalogue.mjs';import {handleRequest} from '../server.mjs';import {Readable} from 'node:stream';
test('catalogue filters and missing price cannot become checkout-ready',()=>{const c=catalogue({category:'corporate-clothing/golf-shirts'});assert.equal(c.total,1);assert.equal(c.products[0].price,null);assert.equal(c.checkoutAvailable,false);assert.equal(catalogue({q:'zzzz'}).total,0);assert.throws(()=>catalogue({page:0}));assert.throws(()=>catalogue({category:'other'}))});
test('quote drafts reject unknown products, duplicate lines and invalid quantities',()=>{for(const items of [[{id:'unknown',quantity:10,branding:'dtf'}],[{id:'golf-shirt',quantity:0,branding:'dtf'}],[{id:'golf-shirt',quantity:1.5,branding:'dtf'}],[{id:'golf-shirt',quantity:10,branding:'free'}],[{id:'golf-shirt',quantity:10,branding:'dtf'},{id:'golf-shirt',quantity:10,branding:'dtf'}]])assert.throws(()=>validateQuoteDraft({items}));assert.equal(validateQuoteDraft({items:[{id:'golf-shirt',quantity:10,branding:'unsure'}]}).priced,false)});
test('request handler validates drafts, rejects cross-origin writes and serves only allowed files',async()=>{
 async function call(url,method='GET',body='',origin='http://localhost:4318'){
 const req=Readable.from(body?[Buffer.from(body)]:[]);Object.assign(req,{url,method,headers:{host:'localhost:4318',origin,'content-type':'application/json'}});
 const res={status:200,headers:{},setHeader(k,v){this.headers[k]=v},writeHead(status,headers){this.status=status;Object.assign(this.headers,headers)},end(body){this.body=body}};
 await handleRequest(req,res);return res;
 }
 const listing=await call('/api/catalogue');assert.equal(listing.status,200);assert.equal(JSON.parse(listing.body).total,12);
 const body=JSON.stringify({items:[{id:'golf-shirt',quantity:25,branding:'embroidery'}]});
 const ok=await call('/api/quote/validate','POST',body);assert.equal(ok.status,200);assert.equal(JSON.parse(ok.body).paymentAvailable,false);
 assert.equal((await call('/api/quote/validate','POST',body,'http://evil.test')).status,403);
 assert.equal((await call('/package.json')).status,404);assert.equal((await call('/api/checkout','POST')).status,405);
 for(const name of ['Inter.ttf','Barlow-SemiBold.ttf']){const font=await call('/fonts/'+name);assert.equal(font.status,200);assert.equal(font.headers['Content-Type'],'font/ttf');assert.ok(font.body.length>100000);}assert.equal((await call('/fonts/../../package.json')).status,404);
 const home=await call('/');assert.equal(home.status,200);assert.match(home.body.toString(),/PRIVATE DESIGN PREVIEW/);
});
