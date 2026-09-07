import './globals.css';
import Link from 'next/link';
import RegisterSW from './pwa/register-sw';
import InstallPWA from './pwa/install';
export const metadata={title:'Tabib.ma — Santé au Maroc',description:'Prise de rendez-vous médicaux et coffre documentaire sécurisé.',manifest:'/manifest.webmanifest',applicationName:'Tabib.ma',appleWebApp:{capable:true,title:'Tabib.ma',statusBarStyle:'default'}};
export const viewport={width:'device-width',initialScale:1,viewportFit:'cover',themeColor:'#0b6bcb'};
export default function RootLayout({children}:{children:React.ReactNode}){return <><RegisterSW/><header className="nav"><Link className="brand" href="/">Tabib.ma</Link><nav className="navlinks"><Link href="/doctors">Médecins</Link><Link href="/documents">Documents</Link><Link href="/dashboard">Espace personnel</Link></nav></header>{children}<InstallPWA/><nav className="bottomnav"><Link href="/">Accueil</Link><Link href="/doctors">Médecins</Link><Link href="/dashboard">RDV</Link><Link href="/documents">Documents</Link></nav><footer className="footer">Tabib.ma · EAGLEYE CORP CFC · Prototype de production à valider juridiquement et sécuritairement avant données de santé réelles.</footer></>}
