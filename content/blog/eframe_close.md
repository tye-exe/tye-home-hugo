+++
date = '2025-09-18T11:41:39+01:00'
draft = false
title = 'Eframe Exploration'
+++

Part one of my bug hunting adventure.

I bring you along on a journey where I attempt to fix [a bug](https://github.com/emilk/egui/issues/6757) in the popular [Eframe](https://github.com/emilk/egui) GUI library, where I could not get the window to close without the program terminating.{{< class "small">}}Or you can jump to the [workaround I found](#workaround){{</ class >}}


## Setting Up Testing

Eframe uses [winit](https://github.com/rust-windowing/winit) to create an application window, so I started my investigation with winit. I verified that winit supports closing the window whilst keeping the application running via testing their "[run_on_demand](https://github.com/rust-windowing/winit/tree/f6893a4390dfe6118ce4b33458d458fd3efd3025/examples)" example, which it does.
This suggests to me that this is not an unsolvable problem, so I hopefully will be able to fix it.

Satisfied that winit is not an immediate problem, I then started investigating the Eframe itself. I cloned the repository and created a minimal application to check the functionality, using my local copy of Eframe, so any modifications I make will take effect.

```rs
use std::time::Duration;

fn main() {
    for _ in 0..2 {
        // Create the eframe application
        eframe::run_native(
            "Egui No Close",
            eframe::NativeOptions::default(),
            Box::new(|cc| Ok(Box::new(MyApp))),
        )
        .expect("Unable to start GUI");

        // Previous window will not close until "run_native" is called again.
        std::thread::sleep(Duration::from_secs(2));
    }
}

struct MyApp;

impl eframe::App for MyApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        // 
    }
}
```

## Modifying Eframe
Since the window does not close, my two immediate suspicions are
- A: A reference to some data is keeping the window open
- B: There is no code to clean up the window when it is "closed"

### Active Event Loop
Looking through the code, the first thing that stuck out is the "src/native/event_loop_context.rs" file, as this contains an [ActiveEventLoop](https://docs.rs/winit/latest/winit/event_loop/struct.ActiveEventLoop.html) type from winit in a [thread local storage](https://doc.rust-lang.org/stable/std/thread/struct.LocalKey.html), the event loop is used to create and run the GUI application in winit, so this seems like a prime target. I attempted to ensure that the ActiveEventLoop was being properly dropped when the window was closed by wrapping the ActiveEventLoop with the following type to report when it has been dropped.

```rs
struct Wrapper<T> {
    inner: T,
}

impl<T> Wrapper<T> {
    fn inner_mut(&mut self) -> &mut T {
        &mut self.inner
    }
}

impl<T> Drop for Wrapper<T> {
    fn drop(&mut self) {
        println!("Dropped Active Event Loop");
    }
}

thread_local! {
    static CURRENT_EVENT_LOOP: Cell<Option<Wrapper<*const ActiveEventLoop>>> = const { Cell::new(None) };
}
```

However, rust complained that "Wrapper" did not implement "Copy", as type "T" in "Cell\<T\>" needs to implement "Copy". The problem is that types that implement "Drop" cannot implement "Copy". Which rust swiftly informed me of.
```sh
Err: error[E0184]: the trait `Copy` cannot be implemented for this type; the type has a destructor
```
Drat!

I got around this by changing the "CURRENT_EVENT_LOOP" to use a [RefCell](https://doc.rust-lang.org/stable/std/cell/struct.RefCell.html). In general I want to change as little of the Eframe source as possible while investigating to avoid modifying the original behaviour, but I could not think of any other option.
This required a few minor changes to the rest of the file to get it to work with a RefCell.

{{< collapsible title="Diff output" >}}
```diff
@@ -1,8 +1,18 @@
-use std::cell::Cell;
+use std::cell::RefCell;
 use winit::event_loop::ActiveEventLoop;
 
+struct Wrapper<T> {
+    inner: T,
+}
+
+impl<T> Drop for Wrapper<T> {
+    fn drop(&mut self) {
+        println!("Dropped Active Event Loop");
+    }
+}
+
 thread_local! {
-    static CURRENT_EVENT_LOOP: Cell<Option<*const ActiveEventLoop>> = const { Cell::new(None) };
+    static CURRENT_EVENT_LOOP: RefCell<Option<Wrapper<*const ActiveEventLoop>>> = const { RefCell::new(None) };
 }
 
 struct EventLoopGuard;
@@ -11,10 +21,12 @@
     fn new(event_loop: &ActiveEventLoop) -> Self {
         CURRENT_EVENT_LOOP.with(|cell| {
             assert!(
-                cell.get().is_none(),
+                cell.borrow().is_none(),
                 "Attempted to set a new event loop while one is already set"
             );
-            cell.set(Some(std::ptr::from_ref::<ActiveEventLoop>(event_loop)));
+            cell.replace(Some(Wrapper {
+                inner: std::ptr::from_ref::<ActiveEventLoop>(event_loop),
+            }));
         });
         Self
     }
@@ -22,7 +34,7 @@
 
 impl Drop for EventLoopGuard {
     fn drop(&mut self) {
-        CURRENT_EVENT_LOOP.with(|cell| cell.set(None));
+        CURRENT_EVENT_LOOP.with(|cell| cell.replace(None));
     }
 }
 
@@ -33,14 +45,14 @@
     F: FnOnce(&ActiveEventLoop) -> R,
 {
     CURRENT_EVENT_LOOP.with(|cell| {
-        cell.get().map(|ptr| {
+        cell.borrow_mut().as_mut().map(|ptr| {
             // SAFETY:
             // 1. The pointer is guaranteed to be valid when it's Some, as the EventLoopGuard that created it
             //    lives at least as long as the reference, and clears it when it's dropped. Only run_with_event_loop creates
             //    a new EventLoopGuard, and does not leak it.
             // 2. Since the pointer was created from a borrow which lives at least as long as this pointer there are
             //    no mutable references to the ActiveEventLoop.
-            let event_loop = unsafe { &*ptr };
+            let event_loop = unsafe { &*ptr.inner };
             f(event_loop)
         })
     })
@@ -52,3 +64,4 @@
     let _guard = EventLoopGuard::new(event_loop);
     f();
 }
+
```
{{</ collapsible >}}


{{< collapsible title="Raw Modified File" >}}
```rs
use std::cell::RefCell;
use winit::event_loop::ActiveEventLoop;

struct Wrapper<T> {
    inner: T,
}

impl<T> Drop for Wrapper<T> {
    fn drop(&mut self) {
        println!("Dropped Active Event Loop");
    }
}

thread_local! {
    static CURRENT_EVENT_LOOP: RefCell<Option<Wrapper<*const ActiveEventLoop>>> = const { RefCell::new(None) };
}

struct EventLoopGuard;

impl EventLoopGuard {
    fn new(event_loop: &ActiveEventLoop) -> Self {
        CURRENT_EVENT_LOOP.with(|cell| {
            assert!(
                cell.borrow().is_none(),
                "Attempted to set a new event loop while one is already set"
            );
            cell.replace(Some(Wrapper {
                inner: std::ptr::from_ref::<ActiveEventLoop>(event_loop),
            }));
        });
        Self
    }
}

impl Drop for EventLoopGuard {
    fn drop(&mut self) {
        CURRENT_EVENT_LOOP.with(|cell| cell.replace(None));
    }
}

// Helper function to safely use the current event loop
#[expect(unsafe_code)]
pub fn with_current_event_loop<F, R>(f: F) -> Option<R>
where
    F: FnOnce(&ActiveEventLoop) -> R,
{
    CURRENT_EVENT_LOOP.with(|cell| {
        cell.borrow_mut().as_mut().map(|ptr| {
            // SAFETY:
            // 1. The pointer is guaranteed to be valid when it's Some, as the EventLoopGuard that created it
            //    lives at least as long as the reference, and clears it when it's dropped. Only run_with_event_loop creates
            //    a new EventLoopGuard, and does not leak it.
            // 2. Since the pointer was created from a borrow which lives at least as long as this pointer there are
            //    no mutable references to the ActiveEventLoop.
            let event_loop = unsafe { &*ptr.inner };
            f(event_loop)
        })
    })
}

// The only public interface to use the event loop
pub fn with_event_loop_context(event_loop: &ActiveEventLoop, f: impl FnOnce()) {
    // NOTE: For safety, this guard must NOT be leaked.
    let _guard = EventLoopGuard::new(event_loop);
    f();
}
```
{{</ collapsible >}}

This showed that the active event loop was getting dropped and recreated for each interaction with the window, which I could have probably deduced from reading the code... There goes about 30 minuets of my life, but I still have a few more things to check.

I modified my wrapper to count how many times the active event loop is dropped, so I can keep track of how often the loop is dropped. As a wall of logs containing the same message makes it hard to tell when messages are being output or if the terminal window is just full.
```rs
use std::{cell::RefCell, ops::Add as _, sync::Mutex};
use winit::event_loop::ActiveEventLoop;

static COUNTER: Mutex<u32> = Mutex::new(0);

struct Wrapper<T> {
    inner: T,
}

impl<T> Drop for Wrapper<T> {
    fn drop(&mut self) {
        let mut mutex_guard = COUNTER.lock().unwrap();
        *mutex_guard = mutex_guard.add(1);
        println!("Dropped Active Event Loop; Occurrence {}", *mutex_guard);
    }
}
```
This showed me that the ActiveEventLoop is dropped three times when the window is "closed".

I wondered if the ActiveEventLoop was set a fourth time, but just never dropped, which could result in the window staying open. I tested this theory by inserting `println!("New Loop")` into "EventLoopGuard::new" (which is called every time the ActiveEventLoop is inserted).

``` bash
Dropped Active Event Loop; Occurrence 258
New Loop
Dropped Active Event Loop; Occurrence 259
New Loop
Dropped Active Event Loop; Occurrence 260
```
It's dropped and that's the end of the story with the ActiveEventLoop.

### External Event Loops
I decided to try using "create_native" as it allows me to use my own event loop to run eframe. This will allow me to directly control the life-cycle of the event loop and ensure that it is not dropped until the application terminates, and no other "funny business".

My first attempt consisted of the following code.
```rs
use std::time::Duration;
use eframe::UserEvent;
use winit::{
    event_loop::{ControlFlow, EventLoop},
    platform::run_on_demand::EventLoopExtRunOnDemand,
};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let native_options = eframe::NativeOptions::default();
    let mut event_loop = EventLoop::<UserEvent>::with_user_event().build()?;
    event_loop.set_control_flow(ControlFlow::Poll);

    let mut winit_app = eframe::create_native(
        "External Event Loop",
        native_options,
        Box::new(|cc| Ok(Box::new(MyApp))),
        &event_loop,
    );

    loop {
        // Run the eframe application on my own event loop.
        event_loop.run_app_on_demand(&mut winit_app)?;
        // Previous window will not close until "run_native" is called again.
        std::thread::sleep(Duration::from_secs(2));
    }
}

struct MyApp;

impl eframe::App for MyApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        //
    }
}
```
However, this panics with the message "Single-use AppCreator has unexpectedly already been taken" on the second iteration of the loop. This error comes from Eframe. It is to do with the `Box::new(|cc| Ok(Box::new(MyApp)))` argument using a [FnOnce](https://doc.rust-lang.org/stable/std/ops/trait.FnOnce.html) type instead of a [Fn](https://doc.rust-lang.org/stable/std/ops/trait.Fn.html) type that implement clone. I modified the Eframe code to use the Fn trait with [Clone](https://doc.rust-lang.org/stable/std/clone/trait.Clone.html), but this had the same effect as moving the "winit_app" creation into the loop. The window remained open after it had been closed.

This means that whatever is causing the behaviour is contained within both the "run_native" and "create_native" code paths within Eframe.

### Maybe It Needs To Be Different

I noticed that the winit example had a attribute of the app that changed each time it was created. I Tested if this would make a difference by passing in a different number each time the loop was executed, using the [black_box](https://doc.rust-lang.org/stable/std/hint/fn.black_box.html) function within [App::update](https://docs.rs/eframe/latest/eframe/trait.App.html#tymethod.update) to ensure that the compiler would not remove the field for optimisation. This however, had no effect on the window closing.
To ensure that the attribute was being changed and kept each time, I just printed it out in the "App::update" function. This did not change anything, other than having some more output in my terminal.

When I tested the winit example without changing the attribute the example still worked as expected, so this has nothing to do with the window closing.

### I Wonder When "Random Type" Is Dropped
Here I go about testing when types that stored with the application by Eframe are dropped. Specifically attributes in "GlowWinitApp", "GlowWInitRunning", and "GlutinWindowContent".

Using the same wrapper struct as earlier, I wrapped the event loop that eframe stores to monitor if it was dropped properly, as it is contained in thread local storage within "src/native/run.rs" in the "with_event_loop" function. After making a few minor modifications to the function so that it is compatible with my wrapper type I was left with this code.
```rs
struct Wrapper<T> {
    inner: T,
}

impl<T> Drop for Wrapper<T> {
    fn drop(&mut self) {
        println!("Dropped Event Loop");
    }
}

thread_local!(static EVENT_LOOP: std::cell::RefCell<Option<Wrapper<EventLoop<UserEvent>>>> = const { std::cell::RefCell::new(None) });

EVENT_LOOP.with(|event_loop| {
    // Since we want to reference NativeOptions when creating the EventLoop we can't
    // do that as part of the lazy thread local storage initialization and so we instead
    // create the event loop lazily here
    let mut event_loop_lock = event_loop.borrow_mut();
    let event_loop = if let Some(event_loop) = &mut *event_loop_lock {
        event_loop
    } else {
        event_loop_lock.insert(Wrapper {
            inner: create_event_loop(&mut native_options)?,
        })
    };
    Ok(f(&mut event_loop.inner, native_options))
})
```
Which showed me that the event loop is only dropped after the application exits, which is the correct behaviour, so it cannot be causing the issue.

---

The egui Viewport contains the winit window, maybe the viewport was not properly being closed was causing the closing issues?

```rs
impl Drop for Viewport {
    fn drop(&mut self) {
        println!("Dropped Viewport");
    }
}
```

This showed that the viewport is being dropped each time the close button is pressed. In-fact, the viewport is dropped the exact instant that the close button is pressed. The same also applies to "GlutinWindowContext", "GlowWinitRunning", and "GlowWinitApp".

---

I changed the Drop method for "egui_glow" (used to interface between egui and [glow](https://github.com/grovesNL/glow)) to log when the [Painter](docs.rs/egui_glow/latest/egui_glow/painter/struct.Painter.html) was dropped, which showed that it is dropped when the window closes.

```rs
impl Drop for Painter {
    fn drop(&mut self) {
        println!("Dropped painter");
        if !self.destroyed {
            log::warn!(
                "You forgot to call destroy() on the egui glow painter. Resources will leak!"
            );
        }
    }
}
```
Furthermore, the painter is also destroyed, as the warning message is not output. This is the correct behaviour, as dropping the painter without destroying it can leak resources, according to the [egui_glow docs](https://docs.rs/egui_glow/latest/egui_glow/painter/struct.Painter.html). Why it is not destroyed whilst it is dropped is a bit of a mystery to me. There is an [open issue about it](https://github.com/emilk/egui/pull/5285), so I guess that this is just open source project things.

---

I checked that the repaint proxy attribute in "GlowWinitApp" does not have any dangling references by outputting the reference counts when "GlowWinitApp" is dropped.
```rs
impl Drop for GlowWinitApp<'_> {
    fn drop(&mut self) {
        println!(
            "Weak: {}, Strong: {}",
            Arc::weak_count(&self.repaint_proxy),
            Arc::strong_count(&self.repaint_proxy)
        );
    }
}
```
It output zero for the weak count and one for the strong count. The one strong reference is from "GlowWinitApp" itself before it is fully dropped, so this is not a concern.

## Maybe I Am The Problem

I am going to try running my test using X11 rather than Wayland. The correct behaviour occurs when using X11; therefore, the issue must be specific to Wayland.
However, the winit example exhibits the correct behaviour on both X11 and Wayland. So the problematic code must not belong to winit, or is in a code path that is not triggered by the example.

### Workaround

I forced [The egui example](https://github.com/tye-exe/egui_no_close) to compile to X11 by unsetting the "WAYLAND_DISPLAY" environment variable. Running the application through XWayland, which resulted in the correct behaviour.
This can be a workaround in the short-term, but my investigations will continue!
