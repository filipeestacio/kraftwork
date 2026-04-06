import { pipeline } from "@huggingface/transformers";

let _pipe: Awaited<ReturnType<typeof pipeline>> | null = null;

async function getPipe() {
  if (!_pipe) {
    _pipe = await pipeline("feature-extraction", "Xenova/all-MiniLM-L6-v2");
  }
  return _pipe;
}

export async function embed(text: string): Promise<number[]> {
  const pipe = await getPipe();
  const out = await pipe(text, { pooling: "mean", normalize: true });
  return Array.from(out.data as Float32Array);
}
