'use client';
import {useEffect,useState} from 'react';
export default function InstallPWA(){
 const [event,setEvent]=useState<any>(null); const [hidden,setHidden]=useState(false);
 useEffect(()=>{const h=(e:any)=>{e.preventDefault();setEvent(e)};window.addEventListener('beforeinstallprompt',h);return()=>window.removeEventListener('beforeinstallprompt',h)},[]);
 if(!event || hidden) return null;
 return <div className="installbar"><div><strong>Installer Tabib.ma</strong><span className="muted">Accès rapide depuis votre téléphone.</span></div><button className="btn" onClick={async()=>{await event.prompt();setHidden(true)}}>Installer</button><button className="btn secondary" onClick={()=>setHidden(true)}>Plus tard</button></div>
}
