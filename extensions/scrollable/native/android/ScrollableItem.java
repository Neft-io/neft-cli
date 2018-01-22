package io.neft.extensions.scrollable_extension;

import android.content.Context;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.HorizontalScrollView;
import android.widget.ScrollView;

import io.neft.renderer.Item;
import io.neft.renderer.NativeItem;
import io.neft.renderer.annotation.OnCreate;
import io.neft.renderer.annotation.OnSet;

public class ScrollableItem extends NativeItem {
    private static class ScrollableView extends ScrollView {
        private ScrollableItem scrollable;
        private HorizontalScrollView hScroll;
        private ViewGroup content;

        class HorizontalScrollableView extends HorizontalScrollView {
            public HorizontalScrollableView(Context context) {
                super(context);
            }

            @Override
            protected void onScrollChanged(int l, int t, int oldl, int oldt) {
                scrollable.sendContentX();
            }
        }

        public ScrollableView(Context context) {
            super(context);

            hScroll = new HorizontalScrollView(context);
            hScroll.setLayoutParams(new LayoutParams(
                    LayoutParams.MATCH_PARENT,
                    LayoutParams.WRAP_CONTENT
            ));
            addView(hScroll);

            content = new FrameLayout(context);
            hScroll.addView(content);
        }

        @Override
        protected void onScrollChanged(int l, int t, int oldl, int oldt) {
            scrollable.sendContentY();
        }

        @Override
        public boolean dispatchTouchEvent(MotionEvent event) {
            hScroll.dispatchTouchEvent(event);
            onTouchEvent(event);
            return true;
        }

        void addContentView(View view) {
            content.addView(view);
        }
    }

    public Item contentItem;

    @OnCreate("Scrollable")
    public ScrollableItem() {
        super(new ScrollableView(APP.getActivity().getApplicationContext()));
        getItemView().scrollable = this;
    }

    private ScrollableView getItemView() {
        return (ScrollableView) itemView;
    }

    private void sendContentX() {
        float scrollX = pxToDp(getItemView().hScroll.getScrollX());
        pushEvent("contentXChange", scrollX);
    }

    private void sendContentY() {
        float scrollY = pxToDp(getItemView().getScrollY());
        pushEvent("contentYChange", scrollY);
    }

    @OnSet("contentItem")
    public void setContentItem(Item val) {
        if (contentItem != null) {
            contentItem.removeFromParent();
        }
        contentItem = val;
        if (val != null) {
            getItemView().addContentView(val.view);
        }
    }

    @OnSet("contentX")
    public void setContentX(int val) {
        int px = Math.round(dpToPx(val));
        getItemView().hScroll.scrollTo(px, 0);
        sendContentX();
    }

    @OnSet("contentY")
    public void setContentY(int val) {
        int px = Math.round(dpToPx(val));
        getItemView().scrollTo(0, px);
        sendContentY();
    }
}
