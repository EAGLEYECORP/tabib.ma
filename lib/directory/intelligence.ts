export type QualityInput={name?:string;specialty?:string;city?:string;address?:string;phone?:string;website?:string;geo?:boolean;verified?:boolean;claimed?:boolean;lastSeenAt?:string}
export function qualityScore(x:QualityInput, now=new Date()):number{
 let s=0
 if(x.name?.trim())s+=.25;if(x.specialty?.trim())s+=.15;if(x.city?.trim())s+=.10;if(x.address?.trim())s+=.10;if(x.phone?.trim())s+=.05;if(x.website?.trim())s+=.05;if(x.geo)s+=.10;if(x.verified)s+=.20;else if(x.claimed)s+=.10
 let freshness=0
 if(x.lastSeenAt){const age=Math.max(0,(now.getTime()-new Date(x.lastSeenAt).getTime())/86400000);freshness=Math.max(0,1-age/180)}
 return Number(Math.min(1,s*(.7+.3*freshness)).toFixed(4))
}
export function distanceKm(a:{lat:number;lng:number},b:{lat:number;lng:number}){const p=Math.PI/180;const dLat=(b.lat-a.lat)*p,dLng=(b.lng-a.lng)*p;const h=Math.sin(dLat/2)**2+Math.cos(a.lat*p)*Math.cos(b.lat*p)*Math.sin(dLng/2)**2;return 6371*2*Math.atan2(Math.sqrt(h),Math.sqrt(1-h))}
export function isStale(lastSeenAt:string|undefined,days=180,now=new Date()){if(!lastSeenAt)return true;return now.getTime()-new Date(lastSeenAt).getTime()>days*86400000}
