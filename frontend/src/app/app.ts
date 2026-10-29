import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { Avisos } from './core/ui';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, Avisos],
  template: `<router-outlet /><app-avisos />`,
})
export class App {}
