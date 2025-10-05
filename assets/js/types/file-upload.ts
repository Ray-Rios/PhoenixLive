// TypeScript interfaces for file handling

export interface FileData {
  name: string;
  type: string;
  size: number;
  data: string | ArrayBuffer | null;
  lastModified: number;
}

export interface ValidatedFile extends File {
  isValid?: boolean;
}