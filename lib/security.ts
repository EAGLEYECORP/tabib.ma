export const MAX_DOCUMENT_BYTES = 25 * 1024 * 1024;
export const ALLOWED_DOCUMENT_TYPES = ['application/pdf','image/jpeg','image/png','image/webp'] as const;
export function safeFilename(name:string) { return name.replace(/[^a-zA-Z0-9._-]/g,'_').slice(0,160) || 'document'; }
export function assertDocument(file: File) {
  if (file.size <= 0 || file.size > MAX_DOCUMENT_BYTES) throw new Error('Document must be between 1 byte and 25 MB.');
  if (!(ALLOWED_DOCUMENT_TYPES as readonly string[]).includes(file.type)) throw new Error('Only PDF, JPEG, PNG and WebP are accepted.');
}
export async function assertDocumentSignature(file: File) {
  const bytes = new Uint8Array(await file.slice(0, 16).arrayBuffer());
  const starts = (sig:number[]) => sig.every((v,i)=>bytes[i]===v);
  const pdf = starts([0x25,0x50,0x44,0x46,0x2D]);
  const jpg = starts([0xFF,0xD8,0xFF]);
  const png = starts([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);
  const webp = starts([0x52,0x49,0x46,0x46]) && bytes[8]===0x57 && bytes[9]===0x45 && bytes[10]===0x42 && bytes[11]===0x50;
  if (!((file.type==='application/pdf'&&pdf)||(file.type==='image/jpeg'&&jpg)||(file.type==='image/png'&&png)||(file.type==='image/webp'&&webp))) throw new Error('FILE_SIGNATURE_MISMATCH');
}
