const now=new Date(2026,10,9,14,20);
let s=42; const rnd=()=>((s=(s*16807)%2147483647)/2147483647);
const mer={Food:['Swiggy','Zomato','Blue Tokai Coffee','Big Basket','Chaayos'],Travel:['Uber','Ola','Metro card','Indian Oil'],Shop:['Amazon','Myntra','Decathlon'],Fun:['BookMyShow','Cult.fit','Steam'],Bills:['BESCOM Electricity','Airtel Fiber','Jio Recharge']};
const T=[];
const mAgo=k=>{const n=new Date(),d=new Date(n.getFullYear(),n.getMonth()-k,1);return{y:d.getFullYear(),m:d.getMonth()}};
for(let k=5;k>=0;k--){const o=mAgo(k);const at=d=>new Date(o.y,o.m,d,12).getTime();const last=k?28:now.getDate();
 T.push(['Salary','Income',142000,at(1)],['Rent','Bills',-32000,at(2)]);
 if(k%2==0)T.push(['LIC','Bills',-12000,at(6)]);
 if(k==2)T.push(['Apollo','Shop',-1850,at(11)]);
 const n=16+(rnd()*6|0);
 for(let j=0;j<n;j++){
  const c=['Food','Food','Food','Travel','Shop','Fun','Bills'][rnd()*7|0],m=mer[c];
  const a=Math.round((c=='Shop'?900+rnd()*3500:c=='Bills'?600+rnd()*1500:c=='Travel'?120+rnd()*500:c=='Fun'?300+rnd()*900:150+rnd()*700)/10)*10;
  const name=m[rnd()*m.length|0];
  const day=Math.max(1,Math.min(last,1+(rnd()*last|0)));
  T.push([name,c,-a,at(day)]);
 }
}
const nov=T.filter(t=>new Date(t[3]).getMonth()==10&&t[3]<=now.getTime()).sort((a,b)=>b[3]-a[3]);
console.log(nov.slice(0,12).map(t=>[t[0],t[1],t[2],new Date(t[3]).toDateString()]));
console.log('count',T.length);
