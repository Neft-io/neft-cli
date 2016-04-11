package io.neft.Renderer;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.graphics.RectF;
import android.os.SystemClock;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.widget.ScrollView;

import java.util.ArrayList;

import io.neft.Client.Action;
import io.neft.Client.InAction;
import io.neft.Client.OutAction;
import io.neft.Client.Reader;
import io.neft.MainActivity;

public class Scrollable extends Item {
    static void register(final MainActivity app) {
        app.client.actions.put(InAction.CREATE_SCROLLABLE, new Action() {
            @Override
            public void work(Reader reader) {
                new Scrollable(app);
            }
        });

        app.client.actions.put(InAction.SET_SCROLLABLE_CONTENT_ITEM, new Action() {
            @Override
            public void work(Reader reader) {
                ((Scrollable) app.renderer.getItemFromReader(reader)).setContentItem(app.renderer.getItemFromReader(reader));
            }
        });

        app.client.actions.put(InAction.SET_SCROLLABLE_CONTENT_X, new Action() {
            @Override
            public void work(Reader reader) {
                ((Scrollable) app.renderer.getItemFromReader(reader)).setContentX(reader.getFloat());
            }
        });

        app.client.actions.put(InAction.SET_SCROLLABLE_CONTENT_Y, new Action() {
            @Override
            public void work(Reader reader) {
                ((Scrollable) app.renderer.getItemFromReader(reader)).setContentY(reader.getFloat());
            }
        });

        app.client.actions.put(InAction.ACTIVATE_SCROLLABLE, new Action() {
            @Override
            public void work(Reader reader) {
                ((Scrollable) app.renderer.getItemFromReader(reader)).activate();
            }
        });
    }

    class ContentView extends View {
        public final Scrollable scrollable;
        public int alpha = 255;

        public ContentView(Scrollable scrollable, Context context) {
            super(context);

            this.scrollable = scrollable;
        }

        @Override
        public void onDraw(Canvas canvas) {
            contentItem.draw(canvas, alpha, scrollable.viewRect);
        }
    }

    class ScrollableView extends ScrollView {
        public final Scrollable scrollable;

        public final ContentView contentView;

        public ScrollableView(Scrollable scrollable, Context context) {
            super(context);

            this.scrollable = scrollable;
            this.contentView = new ContentView(scrollable, context);
            this.addView(contentView);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            return false;
        }

        public void onWindowTouchEvent(MotionEvent event) {
            super.onTouchEvent(event);
        }

        @Override
        public void onScrollChanged(int l, int t, int oldl, int oldt) {
            super.onScrollChanged(l, t, oldl, oldt);

            if (oldl != l) {
                scrollable.contentX = l;
                app.client.pushAction(OutAction.SCROLLABLE_CONTENT_X);
                app.client.pushFloat(l);
            }

            if (oldt != t) {
                scrollable.contentY = t;
                app.client.pushAction(OutAction.SCROLLABLE_CONTENT_Y);
                app.client.pushFloat(t);
            }

            scrollable.invalidate();
            contentView.invalidate();
        }

        @Override
        public void draw(Canvas canvas) {

        }

        public void drawOnItem(final Canvas canvas, final int alpha) {
            if (contentView.alpha != alpha) {
                contentView.alpha = alpha;
                contentView.invalidate();
            }
            super.draw(canvas);
        }
    }

    public final ScrollableView view;
    public Item contentItem;
    public float contentX = 0;
    public float contentY = 0;
    public boolean active = false;
    protected long invalidateDuration = 0;

    private final Matrix contentMatrix = new Matrix();
    public ArrayList<RectF> dirtyRects = new ArrayList<>();
    private Rect dirtyRect = new Rect();
    private RectF viewRect = new RectF();

    public Scrollable(final MainActivity app) {
        super(app);

        this.view = new ScrollableView(this, app.getApplicationContext());
        app.view.addView(view);

        app.view.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                if (active) {
                    view.onWindowTouchEvent(event);
                    invalidate();

                    if (event.getAction() == MotionEvent.ACTION_UP) {
                        active = false;
                        invalidateDuration = 500;
                    }
                }
                return active;
            }
        });
    }

    private void updateViewLayout() {
        view.layout(0, 0, Math.round(width), Math.round(height));
    }

    @Override
    public void setWidth(float val) {
        super.setWidth(val);
        updateViewLayout();
    }

    @Override
    public void setHeight(float val) {
        super.setHeight(val);
        updateViewLayout();
    }

    public void setContentItem(Item item) {
        if (this.contentItem != null) {
            this.contentItem.parent = null;
        }

        this.contentItem = item;
        invalidate();

        if (item != null) {
            item.parent = this;
        }
    }

    public void setContentX(float val) {
        view.scrollBy(Math.round(val), 0);
    }

    public void setContentY(float val) {
        view.scrollBy(0, Math.round(val));
    }

    public void activate() {
        active = true;

        final long now = SystemClock.uptimeMillis();
        final Device device = app.renderer.device;
        final MotionEvent downEvent = MotionEvent.obtain(
                now,
                now,
                MotionEvent.ACTION_DOWN,
                device.pointerDownEventX,
                device.pointerDownEventY,
                0
        );
        view.onWindowTouchEvent(downEvent);
    }

    @Override
    protected void measure(final Matrix globalMatrix, RectF viewRect, final ArrayList<RectF> dirtyRects, final boolean forceUpdateBounds) {
        final boolean finalDirtyMatrix = dirtyMatrix;
        final boolean finalDirtyChildren = dirtyChildren;

        super.measure(globalMatrix, viewRect, dirtyRects, forceUpdateBounds);

        // measure content item
        if (contentItem != null) {
            // layout content view
            final int right = Math.round(contentItem.width);
            final int bottom = Math.round(contentItem.height);
            if (view.contentView.getRight() != right || view.contentView.getBottom() != bottom) {
                view.contentView.layout(0, 0, right, bottom);
            }

            // detect content dirty rectangle
            final boolean forceChildrenUpdate = forceUpdateBounds || finalDirtyMatrix;
            if (forceChildrenUpdate || finalDirtyChildren) {
                contentMatrix.setTranslate(contentX, contentY);

                this.viewRect.set(globalBounds);
                contentMatrix.mapRect(this.viewRect);

                contentItem.measure(this.globalMatrix, this.viewRect, this.dirtyRects, forceChildrenUpdate);
                contentMatrix.setTranslate(-contentX, -contentY);

                if (this.dirtyRects.size() > 0) {
                    for (final RectF rect : this.dirtyRects) {
                        rect.roundOut(dirtyRect);
                        view.contentView.invalidate(dirtyRect);

                        contentMatrix.mapRect(rect);
                        dirtyRects.add(rect);
                    }

                    this.dirtyRects.clear();
                }
            }
        }

        if (invalidateDuration > 0) {
            this.invalidateDuration -= app.view.frameDelay;
            invalidate();
        }

        if (active) {
            invalidate();
        }
    }

    @Override
    protected void drawShape(final Canvas canvas, final int alpha) {
        if (contentItem != null) {
            canvas.translate(-contentX, -contentY);
            view.drawOnItem(canvas, alpha);
            canvas.translate(contentX, contentY);
        }
    }
}
