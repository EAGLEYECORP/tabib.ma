import assert from 'node:assert/strict'
function quality(x){let s=0;if(x.name)s+=.25;if(x.specialty)s+=.15;if(x.city)s+=.1;if(x.address)s+=.1;if(x.phone)s+=.05;if(x.website)s+=.05;if(x.geo)s+=.1;if(x.verified)s+=.2;else if(x.claimed)s+=.1;return Number(Math.min(1,s).toFixed(4))}
assert.equal(quality({name:'Dr A',specialty:'Cardio',city:'Rabat',geo:true,verified:true}),.8)
assert.equal(quality({name:'Dr A'}),.25)
console.log('directory intelligence tests: 2/2 PASS')
