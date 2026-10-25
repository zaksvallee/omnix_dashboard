import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {createHash,timingSafeEqual} from 'node:crypto';
import {categories,catalogue,validateQuoteDraft} from './src/catalogue.mjs';
import {QuoteStore,QuoteError} from './src/quote-store.mjs';
const publicDir=fileURLToPath(new URL('./public/',import.meta.url));
const digest=s=>createHash('sha256').update(s).digest();
export function createHandler({store,staffToken=process.env.SEAMLESS_STAFF_TOKEN??''}={}){
 let repository=store;const buckets=new Map();
 const db=()=>repository??=new QuoteStore(fileURLToPath(new URL('./runtime/seamless.sqlite',import.meta.url)));
 return async function handleRequest(req,res){
  const url=new URL(req.url,'http://localhost'),bearer=req.headers.authorization?.replace(/^Bearer /,'')??'';
  const json=(data,status=200)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
  res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('X-Robots-Tag','noindex, nofollow');res.setHeader('Referrer-Policy','no-referrer');
  res.setHeader('Content-Security-Policy',"default-src 'self'; img-src 'self' https://static.wixstatic.com; style-src 'self'; script-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'");
  try{
   const staff=url.pathname.startsWith('/api/staff/');
   if(staff){if(staffToken.length<32)return json({error:'Staff review is not configured.'},503);if(!timingSafeEqual(digest(bearer),digest(staffToken)))return json({error:'Staff sign-in required.'},401);}
   let body;
   if(req.method==='POST'){
    if(!['/api/quote/validate','/api/quotes'].includes(url.pathname)&&!/^\/api\/staff\/quotes\/[a-f0-9-]{36}$/.test(url.pathname))return json({error:'Method not allowed'},405);
    if(req.headers.origin!==`http://${req.headers.host}`)return json({error:'Use the storefront'},403);
    if(!req.headers['content-type']?.startsWith('application/json'))return json({error:'JSON required'},415);
    let size=0,parts=[];for await(const chunk of req){size+=Buffer.byteLength(chunk);if(size>64000)return json({error:'Request too large'},413);parts.push(Buffer.from(chunk));}body=JSON.parse(Buffer.concat(parts).toString('utf8'));
   }
   if(req.method==='GET'&&url.pathname==='/api/catalogue')return json({...catalogue({q:url.searchParams.get('q')||'',category:url.searchParams.get('category')||'',page:Number(url.searchParams.get('page')||1)}),categories});
   if(req.method==='POST'&&url.pathname==='/api/quote/validate')return json(validateQuoteDraft(body));
   if(req.method==='POST'&&url.pathname==='/api/quotes'){
    const now=Date.now();for(const [key,b]of buckets)if(b.expires<now)buckets.delete(key);
    const key=createHash('sha256').update(req.socket?.remoteAddress??'local').digest('hex'),b=buckets.get(key)??{count:0,expires:now+3600000};
    if(b.count>=10||(!buckets.has(key)&&buckets.size>=2000))return json({error:'Please try again later.'},429);b.count++;buckets.set(key,b);
    return json(db().create(body,req.headers['x-request-token']),201);
   }
   const owned=url.pathname.match(/^\/api\/quotes\/([a-f0-9-]{36})$/);
   if(req.method==='GET'&&owned){const record=db().get(owned[1],bearer);return record?json(record):json({error:'Request not found.'},404);}
   if(req.method==='GET'&&url.pathname==='/api/staff/quotes')return json({quotes:db().list()});
   const review=url.pathname.match(/^\/api\/staff\/quotes\/([a-f0-9-]{36})$/);
   if(req.method==='POST'&&review)return json(db().review(review[1],body));
   if(req.method!=='GET')return json({error:'Method not allowed'},405);
   const routes={'/':'index.html','/app.js':'app.js','/styles.css':'styles.css','/staff':'staff.html','/staff.js':'staff.js','/matrix.js':'matrix.js','/fonts/Inter.ttf':'fonts/Inter.ttf','/fonts/Barlow-SemiBold.ttf':'fonts/Barlow-SemiBold.ttf'};
   if(!Object.hasOwn(routes,url.pathname))return json({error:'Not found'},404);
   const file=routes[url.pathname];res.setHeader('Content-Type',file.endsWith('.ttf')?'font/ttf':file.endsWith('.css')?'text/css':file.endsWith('.js')?'text/javascript':'text/html');res.end(await readFile(path.join(publicDir,file)));
  }catch(e){const publicErrors=['Invalid page','Unknown category','Quantity must be between 1 and 10000','Matrix quantity must equal the item total','Check the colour and size quantities','Duplicate colour and size'];json({error:e instanceof QuoteError||publicErrors.includes(e.message)?e.message:'Check your request and try again'},e.status??400);}
 };
}
export const handleRequest=createHandler();
export function createServer(options){return http.createServer(createHandler(options));}
if(process.argv[1]===fileURLToPath(import.meta.url)){const port=Number(process.env.PORT||4318);createServer().listen(port,'127.0.0.1',()=>console.log(`Seamless preview: http://127.0.0.1:${port}`));}
