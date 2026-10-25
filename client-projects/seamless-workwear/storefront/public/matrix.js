// Requested preferences only; these are not supplier variants or availability.
export function matrixEditor(item,onChange){
 const sizes=['XS','S','M','L','XL','2XL','3XL'],root=document.createElement('details');root.className='matrix-editor';
 const title=document.createElement('summary');title.textContent='Specify preferred colours and sizes';root.append(title);
 const help=document.createElement('p');help.textContent='Enter your preferences. Sizes, colours, stock and branding will be confirmed in your quotation.';root.append(help);
 const scroll=document.createElement('div');scroll.className='matrix-scroll';root.append(scroll);
 const table=document.createElement('table'),head=table.createTHead().insertRow();scroll.append(table);
 for(const label of ['Preferred colour',...sizes,'']){const th=document.createElement('th');th.scope='col';th.textContent=label;head.append(th);}
 const tbody=table.createTBody();let rows=[];
 function update(){const cells=[];for(const row of rows)for(const [size,input]of row.inputs){const n=Number(input.value);if(input.value!==''&&n!==0)cells.push({colour:row.colour.value.trim(),size,quantity:n});}item.requestedVariants=cells;if(cells.length)item.quantity=cells.reduce((sum,c)=>sum+c.quantity,0);onChange(cells.length>0);}
 function add(colour='',values={}){const tr=tbody.insertRow(),cell=tr.insertCell(),input=document.createElement('input');input.placeholder='e.g. Navy';input.maxLength=40;input.value=colour;input.setAttribute('aria-label','Preferred colour');cell.append(input);const row={tr,colour:input,inputs:[]};rows.push(row);input.oninput=update;
  for(const size of sizes){const td=tr.insertCell(),q=document.createElement('input');q.type='number';q.min=0;q.max=10000;q.step=1;q.value=values[size]??'';q.setAttribute('aria-label',size+' requested quantity');q.oninput=update;td.append(q);row.inputs.push([size,q]);}
  const remove=document.createElement('button');remove.type='button';remove.textContent='Remove row';remove.onclick=()=>{rows=rows.filter(r=>r!==row);tr.remove();update()};tr.insertCell().append(remove);
 }
 const grouped=new Map();for(const c of item.requestedVariants??[]){if(!sizes.includes(c.size))continue;if(!grouped.has(c.colour))grouped.set(c.colour,{});grouped.get(c.colour)[c.size]=c.quantity;}
 if(grouped.size)for(const [colour,values]of grouped)add(colour,values);else add();
 const button=document.createElement('button');button.type='button';button.textContent='Add another colour';button.onclick=()=>{if(rows.length<10)add()};root.append(button);return root;
}
