import { readFileSync } from 'node:fs';

export const SOURCE = JSON.parse(readFileSync(new URL('./ftacode-source.json', import.meta.url), 'utf8'));
const toppings = [{ id: 'topping', name: 'Topping thêm', required: false, maxChoices: 4, choices: [
  { id: 'egg', name: 'Trứng', extraVnd: 7000 },
  { id: 'sausage', name: 'Xúc xích', extraVnd: 10000 },
  { id: 'vegetables', name: 'Rau thêm', extraVnd: 3000 },
  { id: 'noodles', name: 'Vắt mì', extraVnd: 7000 },
] }];
export const MENU = SOURCE.items.map(item => ({
  slug: `ftacode-${item.code.toLowerCase()}`,
  name: item.name,
  description: item.description.replace('muỗi nhuyễn', 'muối nhuyễn'),
  priceVnd: item.priceVnd,
  category: 'food',
  prepMinutes: item.sourceCategory === 'Mì trộn' ? 5 : 4,
  imageUrl: item.imageUrl,
}));
export const OPTIONS = Object.fromEntries(SOURCE.items.filter(x => x.sourceCategory === 'Mì trộn')
  .map(x => [`ftacode-${x.code.toLowerCase()}`, toppings]));
