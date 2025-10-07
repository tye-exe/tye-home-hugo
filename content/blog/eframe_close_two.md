+++
date = '2025-09-24T13:17:24+01:00'
draft = false
title = 'Eframe Patch'
+++

Part two of the bug hunting expedition, a continuation of [Eframe Exploration](./eframe_close.md). In which I find the solution to get the application window to *close when you close it*.

## Reproducing The Error
I wondered if the problems is to do with any of [Eframe](https://github.com/emilk/egui)'s dependencies and has already been documented. To find this I used `cargo tree --depth 2` on my minimal project to list the told level dependencies, out of which [Glutin](https://github.com/rust-windowing/glutin) caught my eye, as it is responsible for the lower level rendering of Eframe.

Investigating the Glutin repository I found that it contains [an example](https://github.com/rust-windowing/glutin/blob/0433af9018febe0696c485ed9d66c40dad41f2d4/glutin_examples/src/lib.rs) using [winit](https://github.com/rust-windowing/winit), which after some modification to let it reopen multiple times, also had the exact same issue as Eframe, a fortunate stroke of serendipity! The example is only a few hundred lines of code long, compared to the thousands of Eframe, drastically reducing the amount of code I have to comb through.

**Comments removed for brevity:**
```diff
-pub fn main(event_loop: winit::event_loop::EventLoop<()>) -> Result<(), Box<dyn Error>> {
-    let template =
-        ConfigTemplateBuilder::new().with_alpha_size(8).with_transparency(cfg!(cgl_backend));
+pub fn main(mut event_loop: winit::event_loop::EventLoop<()>) -> Result<(), Box<dyn Error>> {
+    for _ in 0..2 {
+        let template =
+            ConfigTemplateBuilder::new().with_alpha_size(8).with_transparency(cfg!(cgl_backend));

-    let display_builder = DisplayBuilder::new().with_window_attributes(Some(window_attributes()));
+        let display_builder =
+            DisplayBuilder::new().with_window_attributes(Some(window_attributes()));

-    let mut app = App::new(template, display_builder);
-    event_loop.run_app(&mut app)?;
+        use winit::platform::run_on_demand::EventLoopExtRunOnDemand;
+        let mut app = App::new(template, display_builder);
+        event_loop.run_app_on_demand(&mut app)?;

-    app.exit_state
+        std::thread::sleep(std::time::Duration::from_secs(1));
+    }
+    Ok(())
 }
```
---
### Events, Events, Events

I decided to check what events winit is producing for the Glutin example as this might give me extra insight into what exactly is happening with the application. To do this I added a print statement to the "window_event" method.
```rs
fn window_event(
    &mut self,
    event_loop: &ActiveEventLoop,
    _window_id: winit::window::WindowId,
    event: WindowEvent,
) {
    println!("Event: {event:?}");

    // snip //
  }
```

This revealed that the Destroy event was only being triggered after a new window was created to replace the old one, I wonder if this has any significance?

After a tad of internet searching I came across [this issue](https://github.com/rust-windowing/winit/issues/4135), where an application was being left in the exact same "suspended" state. However, the issue was reported for MacOS. Nevertheless, I tried the recommended solution **AND IT WORKED!**. The window closed properly before the next one opened! All it took was dropping the window before exiting the event loop.

```diff
@@ -161,7 +161,10 @@ impl ApplicationHandler for App {
             | WindowEvent::KeyboardInput {
                 event: KeyEvent { logical_key: Key::Named(NamedKey::Escape), .. },
                 ..
-            } => event_loop.exit(),
+            } => {
+                // Drop Window struct
+                self.state.take();
+                event_loop.exit()
+            },
             _ => (),
         }
     }
```
---
## Applying Findings

Investigating Eframe I found the exact same behaviour. The Destroyed event only occurred after the window was recreated
```text {lineNos=inline hl_Lines=[5,6,8,10]}
Event: ScaleFactorChanged { .. }
Event: Resized(PhysicalSize { .. })
Event: Focused(true)
Event: ModifiersChanged(Modifiers { .. })
Event: CloseRequested
### Closed Window ###

Event: ScaleFactorChanged { .. }
Event: Resized(PhysicalSize { .. )
Event: Destroyed
```
6: Close button pressed  
7: Control returned to user code  
8: Rerunning Eframe  
10: Destroyed event triggers after window has been reopened  

### Squashing The Bug
Investigating the Eframe code, I found that it did not differentiate between the "[CloseRequested](https://docs.rs/winit/0.30.12/winit/event/enum.WindowEvent.html#variant.CloseRequested)" and "[Destroyed](https://docs.rs/winit/0.30.12/winit/event/enum.WindowEvent.html#variant.Destroyed)" events. This is the source of the issue.

Eframe creates an abstraction on-top of winit, which resulted in the "CloseRequested" and "Destroyed" events being handled identically by the Eframe "Exit" event (Eframe has its own event system separate to winit).
I created a new "CloseRequested" Eframe event, which dropped the window but did not exit the event loop. And changed the already existing "Exit" Eframe event to only exit the event loop.
Changing Eframe to return "CloseRequested" instead of "Exit" in response to the winit "CloseRequested" event only partially worked. The window closes properly, but the process hangs and does not return execution back to user code.

A potential solution to this is to intercept the winit "Destroyed" event at the Eframe interface to the different renders to immediately return the Eframe "Exit". Though I need to do further testing to ensure this solution is robust.
```rs {hl_Lines=[5]}
let event_result = match event {
    winit::event::WindowEvent::RedrawRequested => {
        self.winit_app.run_ui_and_paint(event_loop, window_id)
    }
    winit::event::WindowEvent::Destroyed => Ok(EventResult::Exit),
    _ => self.winit_app.window_event(event_loop, window_id, event),
};
```

---

After more research I found out that the "Exit" Eframe event is not getting triggered if I do no intercept the "Destroyed" event. This is due to the the implementations for Eframe's renders responding to the window information being gone by waiting instead of exiting.
```diff
if let Some(running) = &mut self.running {
    Ok(running.on_window_event(window_id, &event))
} else {
-    Ok(EventResult::Wait)
+    Ok(EventResult::Exit)
}
```

Both of which now work as expected, and the earlier solution can be removed.
All that is left is to wrap up my changes in a [pull-request](https://github.com/emilk/egui/pull/7565) to the Egui/Eframe repository.

## Le End

And with my [pull-request](https://github.com/emilk/egui/pull/7565) being merged comes the end of my story (*for now*), a personal deep dive into the inner workings of windowing in rust.
