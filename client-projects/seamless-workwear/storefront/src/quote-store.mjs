import {DatabaseSync} from 'node:sqlite';
import {randomUUID,createHash} from 'node:crypto';
import {mkdirSync,chmodSync} from 'node:fs';
import path from 'node:path';
import {validateQuoteDraft} from './catalogue.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
export class QuoteError extends Error{constructor(message,status=400){super(message);this.status=status}}
const text=(v,max,required=false)=>{if(typeof v!=='string'||v.length>max||(required&&!v.trim()))throw new QuoteError('Check your contact details.');return v.trim()};
export function validateRequest(input){
 const draft=validateQuoteDraft(input),c=input.contact;
 if(!c||typeof c!=='object')throw new QuoteError('Contact details are required.');
 const contact={name:text(c.name,100,true),email:text(c.email,254,true),company:text(c.company??'',150),phone:text(c.phone??'',40)};
 if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact.email))throw new QuoteError('Enter a valid email address.');
 return {...draft,contact,notes:text(input.notes??'',2000),status:'needs_review'};
}
export class QuoteStore{
 constructor(filename){
  if(filename!==':memory:'){mkdirSync(path.dirname(filename),{recursive:true,mode:0o700});}
  this.db=new DatabaseSync(filename);
  if(filename!==':memory:')chmodSync(filename,0o600);
  this.db.exec(`PRAGMA foreign_keys=ON; PRAGMA journal_mode=DELETE;
   CREATE TABLE IF NOT EXISTS quotes(id TEXT PRIMARY KEY,owner_hash TEXT UNIQUE NOT NULL,request_hash TEXT NOT NULL,revision INTEGER NOT NULL,status TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
   CREATE TABLE IF NOT EXISTS quote_events(id TEXT PRIMARY KEY,quote_id TEXT NOT NULL REFERENCES quotes(id),revision INTEGER NOT NULL,status TEXT NOT NULL,note TEXT NOT NULL,created_at TEXT NOT NULL,UNIQUE(quote_id,revision));`);
 }
 create(input,token){
  if(!/^[a-f0-9]{64}$/.test(token??''))throw new QuoteError('A private request token is required.');
  const payload=validateRequest(input),json=JSON.stringify(payload),owner=hash(token),digest=hash(json);
  this.db.exec('BEGIN IMMEDIATE');try{
   const prior=this.db.prepare('SELECT id,request_hash FROM quotes WHERE owner_hash=?').get(owner);
   if(prior){if(prior.request_hash!==digest)throw new QuoteError('This submission changed. Start a new request.',409);this.db.exec('COMMIT');return this.get(prior.id,token);}
   const id=randomUUID(),now=new Date().toISOString();
   this.db.prepare('INSERT INTO quotes VALUES (?,?,?,1,?,?,?,?)').run(id,owner,digest,'needs_review',json,now,now);
   this.db.prepare('INSERT INTO quote_events VALUES (?,?,1,?,?,?)').run(randomUUID(),id,'needs_review','Request received; pricing, stock and branding need review.',now);
   this.db.exec('COMMIT');return this.get(id,token);
  }catch(e){this.db.exec('ROLLBACK');throw e}
 }
 view(row,staff=false){if(!row)return null;const payload=JSON.parse(row.payload);return {id:row.id,reference:'SW-'+row.id.slice(0,8).toUpperCase(),revision:row.revision,status:row.status,createdAt:row.created_at,updatedAt:row.updated_at,...payload,status:row.status,price:null,paymentAvailable:false,...(staff?{events:this.db.prepare('SELECT revision,status,note,created_at FROM quote_events WHERE quote_id=? ORDER BY revision').all(row.id)}:{})};}
 get(id,token){if(!/^[a-f0-9]{64}$/.test(token??''))return null;return this.view(this.db.prepare('SELECT * FROM quotes WHERE id=? AND owner_hash=?').get(id,hash(token)));}
 list(){return this.db.prepare('SELECT * FROM quotes ORDER BY updated_at DESC,id LIMIT 100').all().map(r=>this.view(r,true));}
 review(id,{status,note='',expectedRevision}){
  if(!['in_review','awaiting_customer','closed'].includes(status)||!Number.isInteger(expectedRevision))throw new QuoteError('Check the review status and revision.');
  note=text(note,2000);if(!note)throw new QuoteError('Add a review note.');
  this.db.exec('BEGIN IMMEDIATE');try{
   const row=this.db.prepare('SELECT * FROM quotes WHERE id=?').get(id);
   if(!row)throw new QuoteError('Request not found.',404);
   if(row.revision!==expectedRevision)throw new QuoteError('Another reviewer changed this request. Reload before saving.',409);
   if(row.status==='closed')throw new QuoteError('Closed requests cannot be changed.',409);
   const revision=row.revision+1,now=new Date().toISOString();
   this.db.prepare('UPDATE quotes SET status=?,revision=?,updated_at=? WHERE id=?').run(status,revision,now,id);
   this.db.prepare('INSERT INTO quote_events VALUES (?,?,?,?,?,?)').run(randomUUID(),id,revision,status,note,now);
   const result=this.view(this.db.prepare('SELECT * FROM quotes WHERE id=?').get(id),true);this.db.exec('COMMIT');return result;
  }catch(e){this.db.exec('ROLLBACK');throw e}
 }
 close(){this.db.close();}
}
