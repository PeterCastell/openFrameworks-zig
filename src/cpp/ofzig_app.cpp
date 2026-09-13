// The one piece of C++ the bindings need that cpp-bindgen cannot express:
// a subclass. oF drives an app through ofBaseApp's virtual functions, so a
// Zig app needs a C++ object whose vtable forwards each call to a C function
// pointer. `ofzig_callbacks` is mirrored by `Callbacks` in src/app.zig;
// keep the two in the same order.
#include "ofMain.h"

extern "C" {

struct ofzig_callbacks {
    void (*setup)(void*);
    void (*update)(void*);
    void (*draw)(void*);
    void (*exit)(void*);
    void (*key_pressed)(void*, const ofKeyEventArgs*);
    void (*key_released)(void*, const ofKeyEventArgs*);
    void (*mouse_moved)(void*, const ofMouseEventArgs*);
    void (*mouse_dragged)(void*, const ofMouseEventArgs*);
    void (*mouse_pressed)(void*, const ofMouseEventArgs*);
    void (*mouse_released)(void*, const ofMouseEventArgs*);
    void (*mouse_scrolled)(void*, const ofMouseEventArgs*);
    void (*mouse_entered)(void*, const ofMouseEventArgs*);
    void (*mouse_exited)(void*, const ofMouseEventArgs*);
    void (*window_resized)(void*, const ofResizeEventArgs*);
    void (*drag_event)(void*, const ofDragInfo*);
    void (*got_message)(void*, const ofMessage*);
    void (*touch_down)(void*, const ofTouchEventArgs*);
    void (*touch_moved)(void*, const ofTouchEventArgs*);
    void (*touch_up)(void*, const ofTouchEventArgs*);
    void (*touch_double_tap)(void*, const ofTouchEventArgs*);
    void (*touch_cancelled)(void*, const ofTouchEventArgs*);
};

} // extern "C"

namespace {

class ofZigApp : public ofBaseApp {
public:
    ofZigApp(const ofzig_callbacks* c, void* u) : cb(*c), user(u) {}

    // The ofEventArgs overloads are the ones ofEvents dispatches to; the
    // base implementations of these are what forward to the plain ones.
    void setup(ofEventArgs&) override { if (cb.setup) cb.setup(user); }
    void update(ofEventArgs&) override { if (cb.update) cb.update(user); }
    void draw(ofEventArgs&) override { if (cb.draw) cb.draw(user); }
    void exit(ofEventArgs&) override { if (cb.exit) cb.exit(user); }

    void keyPressed(ofKeyEventArgs& a) override { if (cb.key_pressed) cb.key_pressed(user, &a); }
    void keyReleased(ofKeyEventArgs& a) override { if (cb.key_released) cb.key_released(user, &a); }

    void mouseMoved(ofMouseEventArgs& a) override { if (cb.mouse_moved) cb.mouse_moved(user, &a); }
    void mouseDragged(ofMouseEventArgs& a) override { if (cb.mouse_dragged) cb.mouse_dragged(user, &a); }
    void mousePressed(ofMouseEventArgs& a) override { if (cb.mouse_pressed) cb.mouse_pressed(user, &a); }
    void mouseReleased(ofMouseEventArgs& a) override { if (cb.mouse_released) cb.mouse_released(user, &a); }
    void mouseScrolled(ofMouseEventArgs& a) override { if (cb.mouse_scrolled) cb.mouse_scrolled(user, &a); }
    void mouseEntered(ofMouseEventArgs& a) override { if (cb.mouse_entered) cb.mouse_entered(user, &a); }
    void mouseExited(ofMouseEventArgs& a) override { if (cb.mouse_exited) cb.mouse_exited(user, &a); }

    void windowResized(ofResizeEventArgs& a) override { if (cb.window_resized) cb.window_resized(user, &a); }
    void dragged(ofDragInfo& a) override { if (cb.drag_event) cb.drag_event(user, &a); }
    void messageReceived(ofMessage& a) override { if (cb.got_message) cb.got_message(user, &a); }

    void touchDown(ofTouchEventArgs& a) override { if (cb.touch_down) cb.touch_down(user, &a); }
    void touchMoved(ofTouchEventArgs& a) override { if (cb.touch_moved) cb.touch_moved(user, &a); }
    void touchUp(ofTouchEventArgs& a) override { if (cb.touch_up) cb.touch_up(user, &a); }
    void touchDoubleTap(ofTouchEventArgs& a) override { if (cb.touch_double_tap) cb.touch_double_tap(user, &a); }
    void touchCancelled(ofTouchEventArgs& a) override { if (cb.touch_cancelled) cb.touch_cancelled(user, &a); }

private:
    ofzig_callbacks cb;
    void* user;
};

} // namespace

extern "C" {

// Heap-allocated on purpose: ofRunApp(ofBaseApp*) takes ownership and
// deletes the app when the main loop ends.
ofBaseApp* ofzig_app_new(const ofzig_callbacks* cb, void* user) {
    return new ofZigApp(cb, user);
}

size_t ofzig_callbacks_size(void) {
    return sizeof(ofzig_callbacks);
}

} // extern "C"
