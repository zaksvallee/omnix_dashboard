import {test} from 'node:test';
import assert from 'node:assert/strict';
import {categories,categoryTree,catalogue} from '../src/catalogue.mjs';

test('client taxonomy preserves branch identity and complete ancestor chains',()=>{
 assert.deepEqual(categoryTree.map(c=>c.label),['Corporate Clothing','Headwear & Accessories','Sublimation','Workwear PPE','Corporate Gifts','Gift Sets','Display']);
 const ids=new Map(categories.map(c=>[c.id,c]));
 assert.equal(ids.size,categories.length);
 for(const c of categories){if(c.parentId){const parent=ids.get(c.parentId);assert.ok(parent,c.id);assert.equal(c.depth,parent.depth+1);assert.ok(c.id.startsWith(parent.id+'/'));}}
 // Repeated labels remain separate; selecting a department includes its descendants only.
 assert.ok(ids.has('corporate-clothing/footwear'));
 assert.ok(ids.has('workwear-ppe/footwear'));
 assert.equal(catalogue({category:'corporate-clothing/footwear'}).total,0);
 assert.equal(catalogue({category:'workwear-ppe/footwear'}).products[0].id,'safety-footwear');
 const clothing=catalogue({category:'corporate-clothing'}).products;
 assert.ok(clothing.some(p=>p.id==='golf-shirt'));
 assert.ok(clothing.every(p=>p.category.startsWith('corporate-clothing/')));
 assert.ok(ids.has('display/outdoor-products/gazebos/sublimated-gazebos/3m-x-3m-sublimated-gazebos'));
 assert.ok(ids.has('corporate-gifts/key-holders/other-keyholders'));
 assert.equal(catalogue({category:'gift-sets'}).total,0);
 assert.equal(catalogue({category:'gift-sets'}).checkoutAvailable,false);
});
