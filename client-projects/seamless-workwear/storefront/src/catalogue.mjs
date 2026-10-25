import {categories,categoryTree} from './categories.mjs';
export {categories,categoryTree};
export const suppliers=['amrod','barron','captivity','g-fox','salty'];
const categoryAliases={"golfers": "corporate-clothing/golf-shirts", "t-shirts": "corporate-clothing/t-shirts", "jackets": "corporate-clothing/jackets", "pants": "workwear-ppe/bottoms", "footwear": "workwear-ppe/footwear", "high-vis": "workwear-ppe/high-viz", "ppe": "workwear-ppe/headwear/hard-hats", "corporate": "corporate-clothing/dress-shirts", "headwear": "headwear-accessories/caps", "promo": "corporate-gifts/promotional-giveaways", "drinkware": "corporate-gifts/drinkware", "advertising": "display"};
// Discovery records, not imported supplier products. They are never purchasable.
export const products=[
 ['golf-shirt','Golf shirt','golfers','Team-ready polos for a consistent, professional look.','polo'],
 ['cotton-t-shirt','Cotton T-shirt','t-shirts','An everyday starting point for branded teamwear.','tee'],
 ['work-jacket','Workwear jacket','jackets','A practical outer layer for your team.','jacket'],
 ['reflective-vest','Reflective vest','high-vis','High-visibility options for the workday.','vest'],
 ['work-trousers','Work trousers','pants','Find the right fit for your working environment.','pants'],
 ['safety-footwear','Safety footwear','footwear','Discuss your workplace footwear requirements.','boot'],
 ['corporate-shirt','Corporate shirt','corporate','Smart, coordinated clothing for customer-facing teams.','shirt'],
 ['branded-cap','Branded cap','headwear','Finish your team kit with coordinated headwear.','cap'],
 ['drinkware','Branded drinkware','drinkware','Useful everyday items carrying your identity.','bottle'],
 ['promotional-items','Promotional items','promo','Explore useful merchandise for your next campaign.','bag'],
 ['protective-equipment','Protective equipment','ppe','Specify the protection and certification your team needs.','helmet'],
 ['display-items','Advertising displays','advertising','Bring your brand to events, counters and retail spaces.','banner']
].map(([id,name,category,description,illustration])=>({id,name,category:categoryAliases[category],description,illustration,price:null,stock:null,supplier:null,requiresReview:true}));
export function catalogue({q='',category='',page=1}={}){if(!Number.isInteger(page)||page<1||page>1000)throw Error('Invalid page');if(category&&!categories.some(c=>c.id===category))throw Error('Unknown category');const search=String(q).trim().toLowerCase();const rows=products.filter(p=>(!category||(p.category===category||p.category.startsWith(category+'/')))&&(!search||(p.name+' '+p.description).toLowerCase().includes(search)));return {products:rows.slice((page-1)*12,page*12),total:rows.length,page,pageSize:12,mode:'discovery',checkoutAvailable:false};}
export function validateQuoteDraft(input){if(!input||!Array.isArray(input.items)||!input.items.length||input.items.length>50)throw Error('Choose between 1 and 50 items');const seen=new Set();return {items:input.items.map(i=>{if(!products.some(p=>p.id===i.id)||seen.has(i.id))throw Error('Unknown or duplicate item');seen.add(i.id);if(!Number.isInteger(i.quantity)||i.quantity<1||i.quantity>10000)throw Error('Quantity must be between 1 and 10000');if(!['unbranded','embroidery','dtf','screen-print','engraving','unsure'].includes(i.branding))throw Error('Unknown branding method');let requestedVariants=[];
 if(i.requestedVariants!==undefined){
  if(!Array.isArray(i.requestedVariants)||i.requestedVariants.length>100)throw Error('Too many quantity cells');
  const cells=new Set();requestedVariants=i.requestedVariants.map(v=>{
   if(!v||typeof v.colour!=='string'||!v.colour.trim()||v.colour.length>40||typeof v.size!=='string'||!v.size.trim()||v.size.length>20||!Number.isInteger(v.quantity)||v.quantity<1||v.quantity>10000)throw Error('Check the colour and size quantities');
   const colour=v.colour.trim(),size=v.size.trim(),key=JSON.stringify([colour.toLowerCase(),size.toLowerCase()]);if(cells.has(key))throw Error('Duplicate colour and size');cells.add(key);return {colour,size,quantity:v.quantity};
  });
  if(requestedVariants.length&&requestedVariants.reduce((sum,v)=>sum+v.quantity,0)!==i.quantity)throw Error('Matrix quantity must equal the item total');
 }
 return {id:i.id,quantity:i.quantity,branding:i.branding,...(requestedVariants.length?{requestedVariants}:{}),requiresReview:true};}),status:'draft',priced:false,paymentAvailable:false};}
